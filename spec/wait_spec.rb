require 'spec_helper'

RSpec.describe Appom::Wait do
  let(:wait) { Appom::Wait.new(timeout: 1, interval: 0.1) }

  describe '#initialize' do
    it 'sets default timeout and interval' do
      default_wait = Appom::Wait.new
      expect(default_wait.instance_variable_get(:@timeout)).to eq(5)
      expect(default_wait.instance_variable_get(:@interval)).to eq(0.25)
    end

    it 'accepts custom timeout and interval' do
      custom_wait = Appom::Wait.new(timeout: 10, interval: 0.5)
      expect(custom_wait.instance_variable_get(:@timeout)).to eq(10)
      expect(custom_wait.instance_variable_get(:@interval)).to eq(0.5)
    end
  end

  describe '#until' do
    it 'returns result when block returns truthy value' do
      result = wait.until { true }
      expect(result).to be true
    end

    it 'waits and retries when block returns falsy value initially' do
      call_count = 0
      result = wait.until do 
        call_count += 1
        call_count >= 3
      end
      
      expect(result).to be true
      expect(call_count).to eq(3)
    end

    it 'raises error when timeout is reached' do
      expect {
        wait.until { false }
      }.to raise_error(StandardError)
    end

    it 'captures and raises the last error when block raises exceptions' do
      expect {
        wait.until { raise "Test error" }
      }.to raise_error(StandardError, "Test error")
    end
  end
end