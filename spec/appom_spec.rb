require 'spec_helper'

RSpec.describe Appom do
  describe '.configure' do
    it 'allows configuration of max_wait_time' do
      Appom.configure do |config|
        config.max_wait_time = 10
      end
      
      expect(Appom.max_wait_time).to eq(10)
    end
  end

  describe '.register_driver' do
    it 'registers a new driver' do
      mock_driver = double('driver')
      
      driver = Appom.register_driver { mock_driver }
      
      expect(Appom.driver).to eq(mock_driver)
    end
  end

  describe '.start_driver' do
    it 'starts the registered driver' do
      mock_driver = double('driver')
      expect(mock_driver).to receive(:start_driver)
      
      Appom.driver = mock_driver
      Appom.start_driver
    end
  end

  describe '.reset_driver' do
    it 'resets the registered driver' do
      mock_driver = double('driver')
      expect(mock_driver).to receive(:reset)
      
      Appom.driver = mock_driver
      Appom.reset_driver
    end
  end
end