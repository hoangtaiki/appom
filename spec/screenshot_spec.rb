# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'

RSpec.describe Appom::Screenshot do
  let(:test_directory) { Dir.mktmpdir('appom_screenshot_test') }
  let(:mock_driver) { double('driver') }
  let(:mock_element) { double('element') }

  before do
    # Setup mock driver
    allow(Appom).to receive(:driver).and_return(mock_driver)
    allow(mock_driver).to receive(:screenshot)
    allow(mock_driver).to receive(:save_screenshot)
    allow(mock_driver).to receive(:driver).and_return(double('native_driver', screenshot_as: 'base64data'))
    allow(mock_driver).to receive(:respond_to?).with(:screenshot).and_return(true)
    allow(mock_driver).to receive(:respond_to?).with(:save_screenshot).and_return(true)

    # Clean up any existing manager
    described_class.instance_variable_set(:@manager, nil)
  end

  after do
    # Clean up test directory
    FileUtils.rm_rf(test_directory)
  end

  describe Appom::Screenshot::ScreenshotManager do
    subject(:manager) { described_class.new(directory: test_directory) }

    describe '#initialize' do
      it 'creates manager with default settings' do
        manager = described_class.new(directory: test_directory)
        expect(manager.directory).to eq(test_directory)
        expect(manager.format).to eq(:png)
        expect(manager.auto_timestamp).to be(true)
        expect(manager.quality).to eq(90)
      end

      it 'creates manager with custom settings' do
        manager = described_class.new(
          directory: test_directory,
          format: :jpg,
          auto_timestamp: false,
          quality: 75,
        )
        expect(manager.directory).to eq(test_directory)
        expect(manager.format).to eq(:jpg)
        expect(manager.auto_timestamp).to be(false)
        expect(manager.quality).to eq(75)
      end

      it 'validates supported formats' do
        expect { described_class.new(directory: test_directory, format: :gif) }
          .to raise_error(Appom::ConfigurationError)
      end

      it 'creates directory if it does not exist' do
        non_existent_dir = File.join(test_directory, 'new_dir')
        expect(Dir.exist?(non_existent_dir)).to be false

        described_class.new(directory: non_existent_dir)
        expect(Dir.exist?(non_existent_dir)).to be true
      end

      it 'accepts symbol format' do
        manager = described_class.new(directory: test_directory, format: :jpeg)
        expect(manager.format).to eq(:jpeg)
      end

      it 'accepts string format and converts to symbol' do
        manager = described_class.new(directory: test_directory, format: 'jpg')
        expect(manager.format).to eq(:jpg)
      end
    end

    describe '#capture' do
      it 'takes full screen screenshot with default name' do
        filepath = manager.capture

        expect(mock_driver).to have_received(:screenshot)
        expect(filepath).to include(test_directory)
        expect(filepath).to include('screenshot')
        expect(filepath).to end_with('.png')
      end

      it 'takes full screen screenshot with custom name' do
        filepath = manager.capture('test_capture')

        expect(mock_driver).to have_received(:screenshot)
        expect(filepath).to include('test_capture')
      end

      it 'takes element screenshot when element provided' do
        allow(mock_element).to receive(:screenshot)
        filepath = manager.capture('element_shot', element: mock_element)

        expect(mock_element).to have_received(:screenshot)
        expect(filepath).to include('element_shot')
      end

      it 'takes full page screenshot when requested' do
        filepath = manager.capture('full_page', full_page: true)

        expect(mock_driver).to have_received(:save_screenshot)
        expect(filepath).to include('full_page')
      end

      it 'uses custom file path when provided' do
        custom_path = File.join(test_directory, 'custom', 'screenshot.png')
        filepath = manager.capture('test', file_path: custom_path)

        expect(filepath).to eq(custom_path)
        expect(Dir.exist?(File.dirname(custom_path))).to be true
      end

      it 'falls back to base64 screenshot when driver methods unavailable' do
        allow(mock_driver).to receive(:respond_to?).with(:screenshot).and_return(false)
        allow(mock_driver).to receive(:respond_to?).with(:save_screenshot).and_return(false)
        allow(File).to receive(:write)

        manager.capture('fallback')

        expect(File).to have_received(:write).with(anything, Base64.decode64('base64data'), mode: 'wb')
      end

      it 'handles screenshot errors gracefully' do
        allow(mock_driver).to receive(:screenshot).and_raise(StandardError.new('Screenshot failed'))

        filepath = manager.capture('error_test')

        expect(filepath).to be_nil
      end

      it 'increments screenshot count' do
        expect { manager.capture }.to change { manager.stats[:session_count] }.by(1)
      end

      context 'with auto_timestamp disabled' do
        subject(:manager) { described_class.new(directory: test_directory, auto_timestamp: false) }

        it 'generates filename without timestamp' do
          filepath = manager.capture('no_timestamp')

          expect(File.basename(filepath)).to eq('no_timestamp.png')
        end
      end

      context 'with different formats' do
        subject(:manager) { described_class.new(directory: test_directory, format: :jpg) }

        it 'uses specified format in filename' do
          filepath = manager.capture('jpg_test')

          expect(filepath).to end_with('.jpg')
        end
      end
    end

    describe '#capture_on_failure' do
      let(:exception) { StandardError.new('Test failure') }

      before do
        allow(exception).to receive(:backtrace).and_return(%w[line1 line2])
      end

      it 'captures screenshot with failure prefix' do
        filepath = manager.capture_on_failure('test_method')

        expect(filepath).to include('FAIL_test_method')
      end

      it 'sanitizes test name' do
        filepath = manager.capture_on_failure('test::method with spaces!')

        expect(filepath).to include('FAIL_test__method_with_spaces_')
      end

      it 'creates exception info file when exception provided' do
        allow(File).to receive(:write)
        filepath = manager.capture_on_failure('test_method', exception)

        info_file = filepath.gsub(/\.png$/i, '.txt')
        expect(File).to have_received(:write).with(info_file, anything)
      end

      it 'includes exception details in info file' do
        allow(File).to receive(:write)
        manager.capture_on_failure('test_method', exception)

        expect(File).to have_received(:write) do |_, content|
          expect(content).to include('Exception occurred: StandardError')
          expect(content).to include('Message: Test failure')
          expect(content).to include('Backtrace:')
        end
      end

      it 'handles nil exception gracefully' do
        expect { manager.capture_on_failure('test_method', nil) }.not_to raise_error
      end
    end

    describe '#capture_before_after' do
      it 'captures before and after screenshots' do
        result = manager.capture_before_after('action_test') { 'action_result' }

        expect(result[:before]).to include('action_test_BEFORE')
        expect(result[:after]).to include('action_test_AFTER')
        expect(result[:action_result]).to eq('action_result')
      end

      it 'returns action result even if no block given' do
        result = manager.capture_before_after('no_block')

        expect(result[:before]).to include('no_block_BEFORE')
        expect(result[:after]).to include('no_block_AFTER')
        expect(result[:action_result]).to be_nil
      end
    end

    describe '#capture_sequence' do
      it 'captures screenshot sequence during action' do
        allow(Thread).to receive(:new).and_yield
        allow(manager).to receive(:sleep)
        allow(Time).to receive(:now).and_return(0, 1, 2, 15) # Simulate time progression

        result = manager.capture_sequence('sequence_test', interval: 1.0, max_duration: 2.0) { 'completed' }

        expect(result[:directory]).to include('sequence_sequence_test')
        expect(result[:screenshots]).to be_an(Array)
        expect(result[:action_result]).to eq('completed')
        expect(Dir.exist?(result[:directory])).to be true
      end

      it 'creates sequence directory' do
        result = manager.capture_sequence('test_sequence') { nil }

        expect(Dir.exist?(result[:directory])).to be true
        expect(result[:directory]).to include('sequence_test_sequence')
      end

      it 'handles screenshot errors in sequence gracefully' do
        allow(mock_driver).to receive(:screenshot).and_raise(StandardError.new('Sequence error'))

        result = manager.capture_sequence('error_sequence') { 'done' }

        expect(result[:action_result]).to eq('done')
      end
    end

    describe '#cleanup_old_screenshots' do
      before do
        # Create test files with different ages
        old_file = File.join(test_directory, 'old_screenshot.png')
        new_file = File.join(test_directory, 'new_screenshot.png')

        File.write(old_file, 'old')
        File.write(new_file, 'new')

        # Mock file modification times
        old_time = Time.now - (8 * 24 * 60 * 60) # 8 days ago
        new_time = Time.now - (1 * 24 * 60 * 60) # 1 day ago

        allow(File).to receive(:mtime).with(old_file).and_return(old_time)
        allow(File).to receive(:mtime).with(new_file).and_return(new_time)
        allow(File).to receive(:delete)
      end

      it 'deletes files older than specified days' do
        count = manager.cleanup_old_screenshots(days_old: 7)

        expect(File).to have_received(:delete)
        expect(count).to eq(1)
      end

      it 'uses default of 7 days when not specified' do
        allow(File).to receive(:mtime).and_return(Time.now - (8 * 24 * 60 * 60))

        manager.cleanup_old_screenshots

        expect(File).to have_received(:delete).at_least(:once)
      end

      it 'returns zero when no old files exist' do
        allow(File).to receive(:mtime).and_return(Time.now - (1 * 24 * 60 * 60))

        count = manager.cleanup_old_screenshots

        expect(count).to eq(0)
      end
    end

    describe '#stats' do
      context 'when directory exists with files' do
        before do
          File.write(File.join(test_directory, 'test1.png'), 'a' * 1000)
          File.write(File.join(test_directory, 'test2.png'), 'b' * 2000)
          manager.instance_variable_set(:@screenshot_count, 5)
        end

        it 'returns statistics about screenshots' do
          stats = manager.stats

          expect(stats[:total]).to eq(2)
          expect(stats[:size_bytes]).to eq(3000)
          expect(stats[:size_mb]).to eq(0.0)
          expect(stats[:session_count]).to eq(5)
        end
      end

      context 'when directory does not exist' do
        subject(:manager) { described_class.new(directory: '/nonexistent') }

        it 'returns zero statistics' do
          stats = manager.stats

          expect(stats[:total]).to eq(0)
          expect(stats[:size]).to eq(0)
        end
      end
    end

    describe 'private methods' do
      describe '#generate_filename' do
        it 'generates filename with timestamp by default' do
          filename = manager.send(:generate_filename, 'test')

          expect(filename).to start_with('test_')
          expect(filename).to end_with('.png')
          expect(filename).to match(/\d{8}_\d{6}_\d{3}/)
        end

        it 'generates filename without timestamp when disabled' do
          manager_no_timestamp = described_class.new(directory: test_directory, auto_timestamp: false)
          filename = manager_no_timestamp.send(:generate_filename, 'test')

          expect(filename).to eq('test.png')
        end
      end

      describe '#sanitize_name' do
        it 'sanitizes invalid characters' do
          sanitized = manager.send(:sanitize_name, 'test::name with spaces!')

          expect(sanitized).to eq('test__name_with_spaces_')
        end

        it 'handles nil input' do
          sanitized = manager.send(:sanitize_name, nil)

          expect(sanitized).to eq('')
        end

        it 'preserves valid characters' do
          sanitized = manager.send(:sanitize_name, 'test_name-123')

          expect(sanitized).to eq('test_name-123')
        end

        it 'squeezes multiple underscores' do
          sanitized = manager.send(:sanitize_name, 'test___name')

          expect(sanitized).to eq('test_name')
        end
      end

      describe '#validate_format' do
        it 'validates supported formats' do
          expect(manager.send(:validate_format, :png)).to eq(:png)
          expect(manager.send(:validate_format, :jpg)).to eq(:jpg)
          expect(manager.send(:validate_format, :jpeg)).to eq(:jpeg)
        end

        it 'converts string to symbol' do
          expect(manager.send(:validate_format, 'png')).to eq(:png)
        end

        it 'raises error for unsupported format' do
          expect { manager.send(:validate_format, :gif) }
            .to raise_error(Appom::ConfigurationError)
        end
      end

      describe '#format_exception_info' do
        let(:exception) do
          StandardError.new('Test error').tap do |e|
            allow(e).to receive(:backtrace).and_return(%w[line1 line2 line3])
          end
        end

        it 'formats exception information' do
          info = manager.send(:format_exception_info, exception)

          expect(info).to include('Exception occurred: StandardError')
          expect(info).to include('Message: Test error')
          expect(info).to include('Timestamp:')
          expect(info).to include('Backtrace:')
          expect(info).to include('line1')
          expect(info).to include('line2')
        end

        it 'handles nil backtrace' do
          allow(exception).to receive(:backtrace).and_return(nil)

          info = manager.send(:format_exception_info, exception)

          expect(info).to include('Exception occurred: StandardError')
          expect(info).not_to include('line1')
        end
      end
    end
  end

  describe Appom::Screenshot::ScreenshotComparison do
    subject(:comparison) { described_class.new }

    let(:image1_path) { File.join(test_directory, 'image1.png') }
    let(:image2_path) { File.join(test_directory, 'image2.png') }
    let(:output_path) { File.join(test_directory, 'diff.png') }

    before do
      # Create dummy image files
      File.write(image1_path, 'image1_data')
      File.write(image2_path, 'image2_data')
    end

    describe '#initialize' do
      it 'creates comparison with default settings' do
        comp = described_class.new

        expect(comp.instance_variable_get(:@tolerance)).to eq(0.1)
        expect(comp.instance_variable_get(:@highlight_differences)).to be(true)
      end

      it 'creates comparison with custom settings' do
        comp = described_class.new(tolerance: 0.05, highlight_differences: false)

        expect(comp.instance_variable_get(:@tolerance)).to eq(0.05)
        expect(comp.instance_variable_get(:@highlight_differences)).to be(false)
      end
    end

    describe '#compare' do
      context 'when MiniMagick is not available' do
        before do
          allow(comparison).to receive(:require).with('mini_magick').and_raise(LoadError)
        end

        it 'returns nil and logs error' do
          result = comparison.compare(image1_path, image2_path)

          expect(result).to be_nil
        end
      end

      context 'when MiniMagick is available' do
        let(:mock_img1) { double('image1', width: 100, height: 100, dimensions: [100, 100]) }
        let(:mock_img2) { double('image2', width: 100, height: 100, dimensions: [100, 100]) }

        before do
          allow(comparison).to receive(:require).with('mini_magick').and_return(true)

          # Mock MiniMagick::Image
          stub_const('MiniMagick::Image', double('MiniMagick::Image'))
          allow(MiniMagick::Image).to receive(:open).with(image1_path).and_return(mock_img1)
          allow(MiniMagick::Image).to receive(:open).with(image2_path).and_return(mock_img2)

          allow(mock_img1).to receive(:compare).with(mock_img2, 'mae').and_return(0.1)
        end

        it 'compares images and returns similarity percentage' do
          result = comparison.compare(image1_path, image2_path)

          expect(result).to eq(90.0) # (1.0 - 0.1) * 100
        end

        it 'resizes images when dimensions differ' do
          allow(mock_img2).to receive(:dimensions).and_return([200, 200])
          allow(mock_img2).to receive(:resize)

          comparison.compare(image1_path, image2_path)

          expect(mock_img2).to have_received(:resize).with('100x100')
        end

        it 'generates difference image when output path provided' do
          allow(comparison).to receive(:generate_diff_image)

          comparison.compare(image1_path, image2_path, output_path: output_path)

          expect(comparison).to have_received(:generate_diff_image).with(mock_img1, mock_img2, output_path)
        end

        it 'does not generate diff image when highlight_differences is false' do
          comp = described_class.new(highlight_differences: false)
          allow(comp).to receive(:require).with('mini_magick').and_return(true)
          allow(MiniMagick::Image).to receive(:open).with(image1_path).and_return(mock_img1)
          allow(MiniMagick::Image).to receive(:open).with(image2_path).and_return(mock_img2)
          allow(mock_img1).to receive(:compare).and_return(0.1)
          allow(comp).to receive(:generate_diff_image)

          comp.compare(image1_path, image2_path, output_path: output_path)

          expect(comp).not_to have_received(:generate_diff_image)
        end

        it 'handles comparison errors gracefully' do
          allow(mock_img1).to receive(:compare).and_raise(StandardError.new('Comparison failed'))

          result = comparison.compare(image1_path, image2_path)

          expect(result).to be_nil
        end
      end
    end

    describe '#similar?' do
      it 'returns true when images are similar within tolerance' do
        allow(comparison).to receive(:compare).and_return(95.0) # 5% difference

        result = comparison.similar?(image1_path, image2_path, tolerance: 10.0)

        expect(result).to be true
      end

      it 'returns false when images differ more than tolerance' do
        allow(comparison).to receive(:compare).and_return(85.0) # 15% difference

        result = comparison.similar?(image1_path, image2_path, tolerance: 10.0)

        expect(result).to be false
      end

      it 'uses instance tolerance when not specified' do
        comp = described_class.new(tolerance: 15.0)
        allow(comp).to receive(:compare).and_return(90.0) # 10% difference

        result = comp.similar?(image1_path, image2_path)

        expect(result).to be true
      end

      it 'returns false when comparison fails' do
        allow(comparison).to receive(:compare).and_return(nil)

        result = comparison.similar?(image1_path, image2_path)

        expect(result).to be false
      end
    end

    describe 'private methods' do
      describe '#generate_diff_image' do
        let(:mock_img1) { double('image1', path: image1_path) }
        let(:mock_img2) { double('image2', path: image2_path) }
        let(:mock_composite) { double('composite') }
        let(:mock_tool) { double('tool') }

        before do
          stub_const('MiniMagick::Tool::Composite', double('MiniMagick::Tool::Composite'))
          allow(MiniMagick::Tool::Composite).to receive(:new).and_yield(mock_tool).and_return(mock_composite)
          allow(mock_tool).to receive(:compose)
          allow(mock_tool).to receive(:<<)
          allow(mock_composite).to receive(:call)
        end

        it 'creates difference highlight image' do
          comparison.send(:generate_diff_image, mock_img1, mock_img2, output_path)

          expect(mock_tool).to have_received(:compose).with('difference')
          expect(mock_tool).to have_received(:<<).with(image1_path)
          expect(mock_tool).to have_received(:<<).with(image2_path)
          expect(mock_tool).to have_received(:<<).with(output_path)
          expect(mock_composite).to have_received(:call)
        end
      end
    end
  end

  describe 'Module methods' do
    describe '.manager' do
      it 'returns default manager instance' do
        manager = described_class.manager

        expect(manager).to be_a(Appom::Screenshot::ScreenshotManager)
      end

      it 'creates manager with default settings' do
        manager = described_class.manager

        expect(manager.directory).to eq('screenshots')
        expect(manager.format).to eq(:png)
      end

      it 'reuses same manager instance' do
        manager1 = described_class.manager
        manager2 = described_class.manager

        expect(manager1).to be(manager2)
      end
    end

    describe '.configure' do
      it 'creates new manager with specified settings' do
        described_class.configure(directory: test_directory, format: :jpg)

        manager = described_class.manager
        expect(manager.directory).to eq(test_directory)
        expect(manager.format).to eq(:jpg)
      end

      it 'merges with existing settings' do
        # Set initial configuration
        described_class.configure(directory: test_directory, format: :png)

        # Update only format
        described_class.configure(format: :jpg)

        manager = described_class.manager
        expect(manager.directory).to eq(test_directory)
        expect(manager.format).to eq(:jpg)
      end

      it 'handles nil values correctly' do
        described_class.configure(directory: test_directory, auto_timestamp: false)

        # Configure with nil auto_timestamp should preserve existing value
        described_class.configure(directory: test_directory, auto_timestamp: nil)

        manager = described_class.manager
        expect(manager.auto_timestamp).to be(false)
      end
    end

    describe 'convenience methods' do
      let(:mock_manager) { double('manager') }
      let(:mock_comparison) { double('comparison') }

      before do
        allow(described_class).to receive(:manager).and_return(mock_manager)
      end

      describe '.capture' do
        it 'delegates to manager' do
          allow(mock_manager).to receive(:capture)

          described_class.capture('test', element: mock_element)

          expect(mock_manager).to have_received(:capture).with('test', element: mock_element)
        end
      end

      describe '.capture_on_failure' do
        it 'delegates to manager' do
          allow(mock_manager).to receive(:capture_on_failure)
          exception = StandardError.new('test')

          described_class.capture_on_failure('test', exception)

          expect(mock_manager).to have_received(:capture_on_failure).with('test', exception)
        end
      end

      describe '.capture_before_after' do
        it 'delegates to manager with block' do
          allow(mock_manager).to receive(:capture_before_after)

          described_class.capture_before_after('test') { 'result' }

          expect(mock_manager).to have_received(:capture_before_after).with('test')
        end
      end

      describe '.capture_sequence' do
        it 'delegates to manager with options and block' do
          allow(mock_manager).to receive(:capture_sequence)

          described_class.capture_sequence('test', interval: 2.0) { 'result' }

          expect(mock_manager).to have_received(:capture_sequence).with('test', interval: 2.0)
        end
      end

      describe '.cleanup_old' do
        it 'delegates to manager' do
          allow(mock_manager).to receive(:cleanup_old_screenshots)

          described_class.cleanup_old(days_old: 10)

          expect(mock_manager).to have_received(:cleanup_old_screenshots).with(days_old: 10)
        end
      end

      describe '.stats' do
        it 'delegates to manager' do
          allow(mock_manager).to receive(:stats)

          described_class.stats

          expect(mock_manager).to have_received(:stats)
        end
      end

      describe '.compare' do
        it 'creates comparison instance and delegates' do
          allow(Appom::Screenshot::ScreenshotComparison).to receive(:new).and_return(mock_comparison)
          allow(mock_comparison).to receive(:compare)

          described_class.compare('img1.png', 'img2.png', tolerance: 0.05)

          expect(Appom::Screenshot::ScreenshotComparison).to have_received(:new).with(tolerance: 0.05)
          expect(mock_comparison).to have_received(:compare).with('img1.png', 'img2.png')
        end
      end

      describe '.similar?' do
        it 'creates comparison instance and delegates' do
          allow(Appom::Screenshot::ScreenshotComparison).to receive(:new).and_return(mock_comparison)
          allow(mock_comparison).to receive(:similar?)

          described_class.similar?('img1.png', 'img2.png', tolerance: 0.05)

          expect(Appom::Screenshot::ScreenshotComparison).to have_received(:new).with(tolerance: 0.05)
          expect(mock_comparison).to have_received(:similar?).with('img1.png', 'img2.png')
        end
      end
    end
  end
end
