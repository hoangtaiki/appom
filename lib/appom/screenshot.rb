# frozen_string_literal: true

require 'fileutils'
require 'base64'

# Screenshot functionality for Appom automation framework
# Provides screenshot capture, management, and comparison utilities
module Appom::Screenshot
  # Enhanced screenshot utilities with automatic management
  class ScreenshotManager
    include Appom::Logging

    DEFAULT_DIRECTORY = 'screenshots'
    DEFAULT_FORMAT = :png
    SUPPORTED_FORMATS = %i[png jpg jpeg].freeze

    attr_reader :directory, :format, :auto_timestamp, :quality

    def initialize(directory: DEFAULT_DIRECTORY, format: DEFAULT_FORMAT,
                   auto_timestamp: true, quality: 90)
      @directory = directory
      @format = validate_format(format)
      @auto_timestamp = auto_timestamp
      @quality = quality
      @screenshot_count = 0

      ensure_directory_exists
    end

    # Take screenshot with automatic naming
    def capture(name = 'screenshot', element: nil, file_path: nil, full_page: false)
      if file_path
        # Use provided file path
        filepath = file_path
        filename = File.basename(file_path)
        # Ensure directory exists
        FileUtils.mkdir_p(File.dirname(filepath))
      else
        # Generate filename as before
        filename = generate_filename(name)
        filepath = File.join(@directory, filename)
      end

      begin
        if element
          # Element-specific screenshot
          element.screenshot(filepath)
          log_info("Element screenshot saved: #{filename}")
        else
          # Full screen screenshot
          if full_page && driver.respond_to?(:save_screenshot)
            # Use driver's save_screenshot for full page if available
            driver.save_screenshot(filepath)
          elsif driver.respond_to?(:screenshot)
            driver.screenshot(filepath)
          else
            # Fallback for different driver types
            screenshot_data = driver.driver.screenshot_as(:base64)
            File.write(filepath, Base64.decode64(screenshot_data), mode: 'wb')
          end
          log_info("#{full_page ? 'Full page' : 'Full'} screenshot saved: #{filename}")
        end

        @screenshot_count += 1
        filepath
      rescue StandardError => e
        log_error('Failed to take screenshot', { name: name, error: e.message })
        nil
      end
    end

    # Take screenshot on test failure
    def capture_on_failure(test_name, exception = nil)
      name = "FAIL_#{sanitize_name(test_name)}"
      filepath = capture(name)

      if filepath && exception
        # Add exception info to a text file
        info_file = filepath.gsub(/\.(png|jpe?g)$/i, '.txt')
        File.write(info_file, format_exception_info(exception))
      end

      filepath
    end

    # Take before/after comparison screenshots
    def capture_before_after(name)
      before_path = capture("#{name}_BEFORE")

      result = yield if block_given?

      after_path = capture("#{name}_AFTER")

      {
        before: before_path,
        after: after_path,
        action_result: result,
      }
    end

    # Take screenshot sequence during an action
    def capture_sequence(name, interval: 1.0, max_duration: 10.0)
      sequence_dir = File.join(@directory, "sequence_#{sanitize_name(name)}")
      FileUtils.mkdir_p(sequence_dir)

      screenshots = []
      start_time = Time.now
      sequence_count = 0

      # Take initial screenshot
      initial_path = File.join(sequence_dir, "#{sequence_count.to_s.rjust(3, '0')}.#{@format}")
      if driver.respond_to?(:screenshot)
        driver.screenshot(initial_path)
        screenshots << initial_path
        sequence_count += 1
      end

      # Start background screenshot capture
      screenshot_thread = Thread.new do
        while Time.now - start_time < max_duration
          sleep(interval)
          seq_path = File.join(sequence_dir, "#{sequence_count.to_s.rjust(3, '0')}.#{@format}")
          begin
            driver.screenshot(seq_path) if driver.respond_to?(:screenshot)
            screenshots << seq_path
            sequence_count += 1
          rescue StandardError => e
            log_warn("Failed to capture sequence screenshot: #{e.message}")
          end
        end
      end

      # Execute the action
      result = yield if block_given?

      # Stop screenshot capture
      screenshot_thread.kill
      screenshot_thread.join(1.0) # Wait up to 1 second for thread to finish

      log_info("Captured #{screenshots.size} screenshots in sequence")

      {
        directory: sequence_dir,
        screenshots: screenshots,
        count: screenshots.size,
        action_result: result,
      }
    end

    # Clean up old screenshots
    def cleanup_old_screenshots(days_old: 7)
      cutoff_time = Time.now - (days_old * 24 * 60 * 60)
      deleted_count = 0

      Dir.glob(File.join(@directory, '**', '*')).each do |file|
        next unless File.file?(file)

        if File.mtime(file) < cutoff_time
          File.delete(file)
          deleted_count += 1
        end
      end

      log_info("Cleaned up #{deleted_count} old screenshots")
      deleted_count
    end

    # Get screenshot statistics
    def stats
      return { total: 0, size: 0 } unless Dir.exist?(@directory)

      files = Dir.glob(File.join(@directory, '**', '*')).select { |f| File.file?(f) }
      total_size = files.sum { |f| File.size(f) }

      {
        total: files.size,
        size_bytes: total_size,
        size_mb: (total_size / (1024 * 1024.0)).round(2),
        session_count: @screenshot_count,
      }
    end

    private

    def driver
      Appom.driver
    end

    def generate_filename(base_name)
      sanitized = sanitize_name(base_name)
      timestamp = @auto_timestamp ? "_#{Time.now.strftime('%Y%m%d_%H%M%S_%L')}" : ''
      "#{sanitized}#{timestamp}.#{@format}"
    end

    def sanitize_name(name)
      name.to_s.gsub(/[^a-zA-Z0-9_-]/, '_').squeeze('_')
    end

    def validate_format(format)
      format = format.to_sym
      unless SUPPORTED_FORMATS.include?(format)
        raise ConfigurationError.new('screenshot_format', format,
                                     "Must be one of: #{SUPPORTED_FORMATS.join(', ')}",)
      end
      format
    end

    def ensure_directory_exists
      FileUtils.mkdir_p(@directory)
    end

    def format_exception_info(exception)
      <<~INFO
        Exception occurred: #{exception.class}
        Message: #{exception.message}
        Timestamp: #{Time.now}
        Backtrace:
        #{exception.backtrace&.take(10)&.join("\n")}
      INFO
    end
  end

  # Screenshot comparison utilities
  class ScreenshotComparison
    include Appom::Logging

    def initialize(tolerance: 0.1, highlight_differences: true)
      @tolerance = tolerance
      @highlight_differences = highlight_differences
    end

    # Compare two screenshots and return similarity percentage
    def compare(image1_path, image2_path, output_path: nil)
      begin
        require 'mini_magick'
      rescue LoadError
        log_error('MiniMagick gem required for image comparison')
        return nil
      end

      begin
        img1 = MiniMagick::Image.open(image1_path)
        img2 = MiniMagick::Image.open(image2_path)

        # Resize images to same dimensions if needed
        if img1.dimensions != img2.dimensions
          log_warn('Images have different dimensions, resizing for comparison')
          img2.resize("#{img1.width}x#{img1.height}")
        end

        # Compare images
        diff = img1.compare(img2, 'mae') # Mean Absolute Error
        similarity = (1.0 - diff) * 100

        # Generate difference image if requested
        generate_diff_image(img1, img2, output_path) if output_path && @highlight_differences

        log_info("Image comparison: #{similarity.round(2)}% similar")
        similarity
      rescue StandardError => e
        log_error('Image comparison failed', { error: e.message })
        nil
      end
    end

    # Check if images are similar within tolerance
    def similar?(image1_path, image2_path, tolerance: @tolerance)
      similarity = compare(image1_path, image2_path)
      return false unless similarity

      difference = 100 - similarity
      difference <= tolerance
    end

    private

    def generate_diff_image(img1, img2, output_path)
      # Create difference highlight image
      composite = MiniMagick::Tool::Composite.new do |c|
        c.compose('difference')
        c << img1.path
        c << img2.path
        c << output_path
      end
      composite.call
    end
  end

  # Global screenshot instance
  class << self
    attr_writer :manager

    def manager
      @manager ||= ScreenshotManager.new
    end

    # Configure screenshot settings
    def configure(directory: nil, format: nil, auto_timestamp: nil, quality: nil)
      current_config = {
        directory: manager.directory,
        format: manager.format,
        auto_timestamp: manager.auto_timestamp,
        quality: manager.quality,
      }

      new_config = current_config.merge(
        directory: directory || current_config[:directory],
        format: format || current_config[:format],
        auto_timestamp: auto_timestamp.nil? ? current_config[:auto_timestamp] : auto_timestamp,
        quality: quality || current_config[:quality],
      )

      @manager = ScreenshotManager.new(**new_config)
    end

    # Convenience methods
    def capture(name = 'screenshot', **)
      manager.capture(name, **)
    end

    def capture_on_failure(test_name, exception = nil)
      manager.capture_on_failure(test_name, exception)
    end

    def capture_before_after(name, &)
      manager.capture_before_after(name, &)
    end

    def capture_sequence(name, **, &)
      manager.capture_sequence(name, **, &)
    end

    def cleanup_old(days_old: 7)
      manager.cleanup_old_screenshots(days_old: days_old)
    end

    def stats
      manager.stats
    end

    def compare(image1, image2, **)
      ScreenshotComparison.new(**).compare(image1, image2)
    end

    def similar?(image1, image2, **)
      ScreenshotComparison.new(**).similar?(image1, image2)
    end
  end
end
