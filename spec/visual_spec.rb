require 'spec_helper'

RSpec.describe Appom::Visual do
  let(:test_helpers) { Appom::Visual::TestHelpers.new(baseline_dir: 'spec/fixtures/baselines', results_dir: 'spec/fixtures/results') }
  let(:mock_element) { double('element') }
  
  before do
    FileUtils.mkdir_p('spec/fixtures/baselines')
    FileUtils.mkdir_p('spec/fixtures/results')
    
    # Mock element methods
    allow(mock_element).to receive(:location).and_return({ x: 100, y: 200 })
    allow(mock_element).to receive(:size).and_return({ width: 80, height: 30 })
  end

  after do
    FileUtils.rm_rf('spec/fixtures/baselines')
    FileUtils.rm_rf('spec/fixtures/results') 
  end

  describe Appom::Visual::TestHelpers do
    describe '#initialize' do
      it 'creates baseline and results directories' do
        expect(Dir.exist?(test_helpers.baseline_dir)).to be true
        expect(Dir.exist?(test_helpers.results_dir)).to be true
      end

      it 'sets default threshold' do
        expect(test_helpers.threshold).to eq(0.01)
      end

      it 'accepts custom configuration' do
        custom_helpers = Appom::Visual::TestHelpers.new(
          baseline_dir: 'custom/baselines',
          results_dir: 'custom/results',
          threshold: 0.05
        )
        
        expect(custom_helpers.threshold).to eq(0.05)
        expect(custom_helpers.baseline_dir).to include('custom/baselines')
      end
    end

    describe '#visual_regression_test' do
      let(:test_name) { 'login_screen' }
      let(:baseline_path) { File.join(test_helpers.baseline_dir, "#{test_name}.png") }
      let(:current_path) { File.join(test_helpers.results_dir, "#{test_name}_current.png") }

      before do
        # Mock screenshot capture
        allow(test_helpers).to receive(:take_screenshot) do |path|
          File.write(path, "mock_screenshot_#{File.basename(path)}")
          path
        end
      end

      context 'when no baseline exists' do
        it 'creates baseline from current screenshot' do
          result = test_helpers.visual_regression_test(test_name)
          
          expect(result[:baseline_created]).to be true
          expect(result[:passed]).to be true
          expect(File.exist?(baseline_path)).to be true
        end
      end

      context 'when baseline exists' do
        before do
          File.write(baseline_path, 'baseline_content')
        end

        it 'compares current screenshot with baseline' do
          allow(test_helpers).to receive(:compare_images).and_return({
            similarity: 0.99,
            differences: [],
            pixel_differences: 100
          })
          
          result = test_helpers.visual_regression_test(test_name)
          
          expect(result[:passed]).to be true
          expect(result[:comparison][:similarity]).to eq(0.99)
          expect(result[:test_name]).to eq(test_name)
        end

        it 'fails when similarity is below threshold' do
          allow(test_helpers).to receive(:compare_images).and_return({
            similarity: 0.95,
            differences: ['significant_difference'],
            pixel_differences: 5000
          })
          
          result = test_helpers.visual_regression_test(test_name)
          
          expect(result[:passed]).to be false
          expect(result[:comparison][:similarity]).to eq(0.95)
        end

        it 'supports custom baseline path' do
          custom_baseline = 'spec/fixtures/custom_baseline.png'
          
          # Create a mock baseline file
          File.write(custom_baseline, 'custom_baseline_content')
          
          # Mock the file existence check and copy operation
          allow(test_helpers).to receive(:take_screenshot) do |path|
            File.write(path, "mock_screenshot_#{File.basename(path)}")
            path
          end
          
          # Mock compare_images to return passing result
          allow(test_helpers).to receive(:compare_images).and_return({
            similarity: 0.999,  # High similarity to ensure test passes
            differences: [],
            pixel_differences: 25
          })
          
          result = test_helpers.visual_regression_test(test_name, baseline: custom_baseline)
          
          expect(result[:baseline_path]).to eq(custom_baseline)
          expect(result[:passed]).to be true
          expect(result[:comparison][:similarity]).to eq(0.999)
          
          # Clean up
          File.delete(custom_baseline) if File.exist?(custom_baseline)
        end
      end
    end

    describe '#take_visual_screenshot' do
      let(:screenshot_name) { 'test_screenshot' }

      before do
        allow(test_helpers).to receive(:take_screenshot) do |path|
          File.write(path, "screenshot_content")
          path
        end
      end

      it 'takes screenshot with timestamp' do
        path = test_helpers.take_visual_screenshot(screenshot_name)
        
        expect(File.exist?(path)).to be true
        expect(path).to include(screenshot_name)
        expect(path).to match(/\d{8}_\d{6}/)
      end

      it 'adds annotations when provided' do
        annotations = [
          { type: :rectangle, x: 10, y: 20, width: 100, height: 50, color: 'red' }
        ]
        
        allow(test_helpers).to receive(:annotate_screenshot).and_return('annotated_path.png')
        
        path = test_helpers.take_visual_screenshot(screenshot_name, annotations: annotations)
        
        expect(path).to include('annotated')
      end
    end

    describe '#compare_element_visuals' do
      let(:baseline_name) { 'button_element' }

      before do
        allow(test_helpers).to receive(:take_element_screenshot).and_return('element_screenshot.png')
      end

      context 'when baseline exists' do
        before do
          baseline_path = File.join(test_helpers.baseline_dir, "#{baseline_name}_element.png")
          File.write(baseline_path, 'element_baseline')
        end

        it 'compares element with baseline' do
          # Create a mock baseline file
          baseline_path = File.join(test_helpers.baseline_dir, "#{baseline_name}_element.png")
          
          # Mock the element screenshot creation
          allow(test_helpers).to receive(:take_element_screenshot) do |element|
            screenshot_path = File.join(test_helpers.results_dir, "element_screenshot.png")
            File.write(screenshot_path, 'element_screenshot_content')
            screenshot_path
          end
          
          # Mock compare_images with high similarity to ensure test passes
          allow(test_helpers).to receive(:compare_images).and_return({
            similarity: 0.995,  # High similarity to pass default threshold
            differences: []
          })
          
          result = test_helpers.compare_element_visuals(mock_element, baseline_name)
          
          expect(result[:similarity]).to eq(0.995)
          expect(result[:passed]).to be true
        end

        it 'supports custom threshold' do
          # Mock element screenshot creation
          allow(test_helpers).to receive(:take_element_screenshot) do |element|
            screenshot_path = File.join(test_helpers.results_dir, "element_screenshot.png")
            File.write(screenshot_path, 'element_screenshot_content')
            screenshot_path
          end
          
          # Use similarity that passes with custom threshold
          allow(test_helpers).to receive(:compare_images).and_return({
            similarity: 0.95,  # This should pass with threshold 0.1 (90% requirement)
            differences: []
          })
          
          result = test_helpers.compare_element_visuals(mock_element, baseline_name, threshold: 0.1)
          
          expect(result[:passed]).to be true
          expect(result[:similarity]).to eq(0.95)
        end
      end

      context 'when no baseline exists' do
        it 'creates baseline from element screenshot' do
          # Mock the element screenshot creation
          allow(test_helpers).to receive(:take_element_screenshot) do |element|
            screenshot_path = File.join(test_helpers.results_dir, "element_screenshot.png")
            File.write(screenshot_path, 'element_screenshot_content')
            screenshot_path
          end
          
          # Mock FileUtils.cp to avoid actual file operations
          allow(FileUtils).to receive(:cp) do |src, dest|
            File.write(dest, File.read(src))
          end
          
          result = test_helpers.compare_element_visuals(mock_element, baseline_name)
          
          expect(result[:baseline_created]).to be true
          expect(result[:baseline_path]).to include("#{baseline_name}_element.png")
        end
      end
    end

    describe '#visual_diff' do
      let(:image1_path) { 'spec/fixtures/image1.png' }
      let(:image2_path) { 'spec/fixtures/image2.png' }

      before do
        File.write(image1_path, 'image1_content')
        File.write(image2_path, 'image2_content')
        
        allow(test_helpers).to receive(:compare_images).and_return({
          similarity: 0.85,
          differences: ['color_difference', 'size_difference']
        })
      end

      after do
        [image1_path, image2_path].each { |path| File.delete(path) if File.exist?(path) }
      end

      it 'creates visual diff between two images' do
        result = test_helpers.visual_diff(image1_path, image2_path)
        
        expect(result[:image1]).to eq(image1_path)
        expect(result[:image2]).to eq(image2_path)
        expect(result[:similarity]).to eq(0.85)
        expect(result[:differences_found]).to be true
      end

      it 'supports custom output path' do
        output_path = 'spec/fixtures/custom_diff.png'
        result = test_helpers.visual_diff(image1_path, image2_path, output_path)
        
        expect(result[:diff]).to eq(output_path)
      end
    end

    describe '#highlight_element' do
      before do
        allow(test_helpers).to receive(:take_screenshot).and_return('temp_screenshot.png')
        allow(test_helpers).to receive(:annotate_screenshot).and_return('highlighted.png')
      end

      it 'highlights element in screenshot' do
        path = test_helpers.highlight_element(mock_element)
        
        expect(path).to include('highlighted_element')
      end

      it 'supports custom highlight options' do
        path = test_helpers.highlight_element(mock_element, color: 'blue', thickness: 5)
        
        expect(path).to be_a(String)
      end
    end

    describe '#capture_element_sequence' do
      before do
        allow(test_helpers).to receive(:take_element_screenshot) do |element, name|
          "#{name}.png"
        end
      end

      it 'captures sequence of element screenshots' do
        frames = test_helpers.capture_element_sequence(mock_element, duration: 0.1, interval: 0.05)
        
        expect(frames).to be_an(Array)
        expect(frames.size).to be >= 2
        expect(frames.first[:path]).to include('sequence_frame_0')
        expect(frames.first[:frame_number]).to eq(0)
        expect(frames.first[:timestamp]).to be >= 0
      end

      it 'supports custom name prefix' do
        frames = test_helpers.capture_element_sequence(mock_element, duration: 0.1, name_prefix: 'animation')
        
        expect(frames.first[:path]).to include('animation_frame_0')
      end
    end

    describe '#wait_for_visual_stability' do
      before do
        @screenshot_count = 0
        allow(test_helpers).to receive(:take_screenshot) do |path|
          @screenshot_count += 1
          File.write(path, "screenshot_#{@screenshot_count}")
          path
        end
        
        allow(test_helpers).to receive(:take_element_screenshot) do |element|
          @screenshot_count += 1
          path = "element_screenshot_#{@screenshot_count}.png"
          File.write(path, "element_screenshot_#{@screenshot_count}")
          path
        end
      end

      it 'waits for visual stability of page' do
        allow(test_helpers).to receive(:compare_images).and_return({ similarity: 1.0 })
        
        result = test_helpers.wait_for_visual_stability(duration: 0.1, check_interval: 0.05)
        
        expect(result).to be true
      end

      it 'waits for visual stability of element' do
        allow(test_helpers).to receive(:compare_images).and_return({ similarity: 1.0 })
        
        result = test_helpers.wait_for_visual_stability(element: mock_element, duration: 0.1)
        
        expect(result).to be true
      end
    end

    describe '#results_summary' do
      before do
        # Reset comparison results before each test
        test_helpers.instance_variable_set(:@comparison_results, [])
        
        allow(test_helpers).to receive(:take_screenshot) { |path| File.write(path, 'screenshot'); path }
        allow(test_helpers).to receive(:compare_images).and_return({ similarity: 0.98 })
        
        # Run exactly 2 tests
        test_helpers.visual_regression_test('test1')
        test_helpers.visual_regression_test('test2')
      end

      it 'provides comprehensive results summary' do
        summary = test_helpers.results_summary
        
        expect(summary[:tests_run]).to eq(2)
        expect(summary[:passed]).to be >= 0
        expect(summary[:pass_rate]).to be_a(Numeric)
        expect(summary[:results]).to be_an(Array)
        expect(summary[:threshold]).to eq(0.01)
      end
    end

    describe '#generate_report' do
      before do
        allow(test_helpers).to receive(:take_screenshot) { |path| File.write(path, 'screenshot'); path }
        allow(test_helpers).to receive(:compare_images).and_return({ similarity: 0.95 })
        
        # Add comparison results for report
        test_helpers.instance_variable_set(:@comparison_results, [
          { test_name: 'report_test', passed: true, timestamp: Time.now }
        ])
        
        test_helpers.visual_regression_test('report_test')
      end

      it 'generates HTML report' do
        report_path = test_helpers.generate_report(output_file: 'spec/fixtures/test_report.html')
        
        expect(File.exist?(report_path)).to be true
        content = File.read(report_path)
        expect(content).to include('<html>')
        expect(content).to include('Visual Test Report')
        expect(content).to include('report_test')
        
        File.delete(report_path)
      end
    end

    describe '#update_baselines' do
      before do
        allow(test_helpers).to receive(:take_screenshot) { |path| File.write(path, 'new_content'); path }
        allow(test_helpers).to receive(:compare_images).and_return({ similarity: 0.95 })
        
        File.write(File.join(test_helpers.baseline_dir, 'update_test.png'), 'old_baseline')
        test_helpers.visual_regression_test('update_test')
      end

      it 'updates all baselines when no test names specified' do
        updated_count = test_helpers.update_baselines
        
        expect(updated_count).to eq(1)
        baseline_content = File.read(File.join(test_helpers.baseline_dir, 'update_test.png'))
        expect(baseline_content).to eq('new_content')
      end

      it 'updates only specified test baselines' do
        updated_count = test_helpers.update_baselines(['update_test'])
        
        expect(updated_count).to eq(1)
      end
    end
  end

  describe 'Global Visual module' do
    before do
      Appom::Visual.clear_results!
      allow(Appom::Visual.test_helpers).to receive(:take_screenshot) do |path|
        File.write(path, 'global_screenshot')
        path
      end
    end

    describe '.regression_test' do
      it 'uses global test helpers' do
        allow(Appom::Visual.test_helpers).to receive(:visual_regression_test).and_return({
          test_name: 'global_test',
          passed: true
        })
        
        result = Appom::Visual.regression_test('global_test')
        
        expect(result[:test_name]).to eq('global_test')
      end
    end

    describe '.results_summary' do
      it 'returns global results summary' do
        allow(Appom::Visual.test_helpers).to receive(:results_summary).and_return({
          tests_run: 1,
          passed: 1,
          failed: 0
        })
        
        summary = Appom::Visual.results_summary
        
        expect(summary[:tests_run]).to eq(1)
      end
    end
  end

  describe Appom::Visual::DSL do
    let(:test_class) do
      dsl_module = Appom::Visual::DSL
      Class.new do
        include dsl_module
        
        attr_reader :mock_element
        
        def initialize
          # Use method_missing to handle double call
        end
        
        private
        
        def method_missing(name, *args, &block)
          if name == :double
            double(*args, &block)
          else
            super
          end
        end
        
        def respond_to_missing?(name, include_private = false)
          name == :double || super
        end
      end
    end

    let(:test_instance) { test_class.new }

    before do
      allow(test_class.visual_test_helper).to receive(:visual_regression_test).and_return({ passed: true })
      allow(test_class.visual_test_helper).to receive(:take_visual_screenshot).and_return('screenshot.png')
    end

    describe 'class methods' do
      it 'provides visual test helper' do
        expect(test_class.visual_test_helper).to be_a(Appom::Visual::TestHelpers)
      end

      it 'allows setting custom baseline directory' do
        test_class.visual_baseline_dir('custom/baselines')
        helper = test_class.visual_test_helper
        expect(helper.instance_variable_get(:@baseline_dir)).to include('custom/baselines')
      end

      it 'allows setting custom results directory' do
        test_class.visual_results_dir('custom/results')
        helper = test_class.visual_test_helper
        expect(helper.instance_variable_get(:@results_dir)).to include('custom/results')
      end

      it 'allows setting custom threshold' do
        test_class.visual_threshold(0.05)
        helper = test_class.visual_test_helper
        expect(helper.instance_variable_get(:@threshold)).to eq(0.05)
      end
    end

    describe 'instance methods' do
      it 'provides visual regression test method' do
        result = test_instance.visual_regression_test('dsl_test')
        expect(result[:passed]).to be true
      end

      it 'provides visual screenshot method' do
        path = test_instance.visual_screenshot('dsl_screenshot')
        expect(path).to eq('screenshot.png')
      end
    end
  end
end