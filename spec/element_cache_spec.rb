# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Appom::ElementCache do
  let(:mock_element) { double('element') }
  let(:cache) { Appom::ElementCache::Cache.new(max_size: 3, ttl: 1) }

  describe Appom::ElementCache::Cache do
    describe '#initialize' do
      it 'initializes with default values' do
        default_cache = described_class.new
        expect(default_cache.max_size).to eq(100)
        expect(default_cache.ttl).to eq(300)
        expect(default_cache.size).to eq(0)
      end

      it 'accepts custom configuration' do
        expect(cache.max_size).to eq(3)
        expect(cache.ttl).to eq(1)
      end
    end

    describe '#store' do
      it 'stores element with generated key' do
        key = cache.store(:id, 'test_button', mock_element)

        expect(cache.size).to eq(1)
        expect(cache.hit?(key)).to be true
        expect(cache.statistics[:stores]).to eq(1)
      end

      it 'generates consistent keys for same locator' do
        key1 = cache.store(:id, 'test_button', mock_element)
        key2 = cache.store(:id, 'test_button', double('element2'))

        expect(key1).to eq(key2)
        expect(cache.size).to eq(1) # Should overwrite
      end

      it 'generates different keys for different locators' do
        key1 = cache.store(:id, 'button1', mock_element)
        key2 = cache.store(:id, 'button2', mock_element)

        expect(key1).not_to eq(key2)
        expect(cache.size).to eq(2)
      end

      it 'updates existing entries' do
        key = cache.store(:id, 'test_button', mock_element)
        new_element = double('new_element')

        cache.store(:id, 'test_button', new_element)

        expect(cache.size).to eq(1)
        expect(cache.get(key)).to eq(new_element)
      end
    end

    describe '#get' do
      let(:key) { cache.store(:id, 'test_button', mock_element) }

      it 'retrieves stored element' do
        element = cache.get(key)

        expect(element).to eq(mock_element)
        expect(cache.statistics[:hits]).to eq(1)
      end

      it 'returns nil for non-existent key' do
        element = cache.get('nonexistent_key')

        expect(element).to be_nil
        expect(cache.statistics[:misses]).to eq(1)
      end

      it 'moves accessed element to front (LRU)' do
        key1 = cache.store(:id, 'button1', double('element1'))
        key2 = cache.store(:id, 'button2', double('element2'))
        key3 = cache.store(:id, 'button3', double('element3'))

        # Access first element
        cache.get(key1)

        # Add fourth element, should evict second element (least recently used)
        cache.store(:id, 'button4', double('element4'))

        expect(cache.hit?(key1)).to be true  # Recently accessed, should remain
        expect(cache.hit?(key2)).to be false # Should be evicted
        expect(cache.hit?(key3)).to be true  # Should remain
      end
    end

    describe '#hit?' do
      it 'returns true for cached elements' do
        key = cache.store(:id, 'test_button', mock_element)

        expect(cache.hit?(key)).to be true
      end

      it 'returns false for non-cached elements' do
        expect(cache.hit?('nonexistent_key')).to be false
      end
    end

    describe 'LRU eviction' do
      it 'evicts least recently used elements when max size reached' do
        # Fill cache to max capacity
        key1 = cache.store(:id, 'button1', double('element1'))
        key2 = cache.store(:id, 'button2', double('element2'))
        key3 = cache.store(:id, 'button3', double('element3'))

        expect(cache.size).to eq(3)

        # Add fourth element, should evict first
        key4 = cache.store(:id, 'button4', double('element4'))

        expect(cache.size).to eq(3)
        expect(cache.hit?(key1)).to be false # Evicted
        expect(cache.hit?(key2)).to be true
        expect(cache.hit?(key3)).to be true
        expect(cache.hit?(key4)).to be true
      end

      it 'updates LRU order on access' do
        key1 = cache.store(:id, 'button1', double('element1'))
        key2 = cache.store(:id, 'button2', double('element2'))
        key3 = cache.store(:id, 'button3', double('element3'))

        # Access first element to make it most recently used
        cache.get(key1)

        # Add fourth element, should evict second element
        cache.store(:id, 'button4', double('element4'))

        expect(cache.hit?(key1)).to be true  # Recently accessed
        expect(cache.hit?(key2)).to be false # Should be evicted
        expect(cache.hit?(key3)).to be true
        expect(cache.size).to eq(3)
      end
    end

    describe 'TTL expiration' do
      it 'expires elements after TTL', :slow do
        key = cache.store(:id, 'test_button', mock_element)

        expect(cache.hit?(key)).to be true

        sleep(1.1) # Wait for TTL to expire

        expect(cache.hit?(key)).to be false
        expect(cache.get(key)).to be_nil
      end

      it 'updates TTL on access' do
        key = cache.store(:id, 'test_button', mock_element)

        sleep(0.5)
        cache.get(key) # Should refresh TTL
        sleep(0.7)     # Total 1.2s, but accessed at 0.5s

        expect(cache.hit?(key)).to be true # Should still be valid
      end

      it 'cleans up expired entries' do
        key1 = cache.store(:id, 'button1', double('element1'))

        sleep(1.1) # Let first element expire

        key2 = cache.store(:id, 'button2', double('element2'))

        # Cleanup should have removed expired element
        expect(cache.size).to eq(1)
        expect(cache.hit?(key1)).to be false
        expect(cache.hit?(key2)).to be true
      end
    end

    describe '#clear' do
      it 'removes all cached elements' do
        cache.store(:id, 'button1', double('element1'))
        cache.store(:id, 'button2', double('element2'))

        expect(cache.size).to eq(2)

        cache.clear

        expect(cache.size).to eq(0)
        expect(cache.statistics[:clears]).to eq(1)
      end
    end

    describe '#statistics' do
      it 'tracks comprehensive statistics' do
        stats = cache.statistics

        expect(stats[:hits]).to eq(0)
        expect(stats[:misses]).to eq(0)
        expect(stats[:stores]).to eq(0)
        expect(stats[:evictions]).to eq(0)
        expect(stats[:expirations]).to eq(0)
        expect(stats[:clears]).to eq(0)
        expect(stats[:hit_rate]).to eq(0.0)
      end

      it 'calculates hit rate correctly' do
        key = cache.store(:id, 'test_button', mock_element)

        cache.get(key)      # Hit
        cache.get(key)      # Hit
        cache.get('missing') # Miss

        stats = cache.statistics
        expect(stats[:hits]).to eq(2)
        expect(stats[:misses]).to eq(1)
        expect(stats[:hit_rate]).to eq(66.67)
      end

      it 'tracks evictions' do
        cache.store(:id, 'button1', double('element1'))
        cache.store(:id, 'button2', double('element2'))
        cache.store(:id, 'button3', double('element3'))
        cache.store(:id, 'button4', double('element4')) # Should cause eviction

        expect(cache.statistics[:evictions]).to eq(1)
      end
    end

    describe 'cache key generation' do
      it 'generates consistent keys for same locator strategy and value' do
        key1 = cache.generate_key(:id, 'test_button')
        key2 = cache.generate_key(:id, 'test_button')

        expect(key1).to eq(key2)
      end

      it 'generates different keys for different strategies' do
        key1 = cache.generate_key(:id, 'test_button')
        key2 = cache.generate_key(:class, 'test_button')

        expect(key1).not_to eq(key2)
      end

      it 'generates different keys for different values' do
        key1 = cache.generate_key(:id, 'button1')
        key2 = cache.generate_key(:id, 'button2')

        expect(key1).not_to eq(key2)
      end

      it 'handles complex locator values' do
        complex_value = { contains: 'text', index: 2 }
        key = cache.generate_key(:xpath, complex_value)

        expect(key).to be_a(String)
        expect(key.length).to eq(32) # MD5 hash length
      end
    end
  end

  describe Appom::ElementCache::CacheAwareFinder do
    let(:test_class) do
      Class.new do
        include Appom::ElementCache::CacheAwareFinder

        def original_find_element(_strategy, _locator)
          # Return a simple mock object
          mock_element = Object.new
          mock_element.define_singleton_method(:displayed?) { true }
          mock_element.define_singleton_method(:enabled?) { true }
          mock_element
        end

        def original_find_elements(_strategy, _locator)
          # Return array of mock objects
          elements = []
          2.times do |_i|
            element = Object.new
            element.define_singleton_method(:displayed?) { true }
            element.define_singleton_method(:enabled?) { true }
            elements << element
          end
          elements
        end
      end
    end

    let(:finder) { test_class.new }

    before do
      Appom::ElementCache.reset_cache
    end

    describe '#find_element' do
      it 'uses cache for repeated lookups' do
        element1 = finder.find_element(:id, 'test_button')
        element2 = finder.find_element(:id, 'test_button')

        expect(element2).to eq(element1) # Should return cached element

        cache_stats = Appom::ElementCache.cache_statistics
        expect(cache_stats[:hits]).to eq(1)
        expect(cache_stats[:stores]).to eq(1)
      end

      it 'calls original method on cache miss' do
        expect(finder).to receive(:original_find_element).with(:id, 'new_button').and_call_original

        element = finder.find_element(:id, 'new_button')
        expect(element).not_to be_nil
      end

      it 'caches found elements' do
        element = finder.find_element(:class, 'button_class')

        cache_stats = Appom::ElementCache.cache_statistics
        expect(cache_stats[:stores]).to eq(1)

        # Second call should hit cache
        cached_element = finder.find_element(:class, 'button_class')
        expect(cached_element).to eq(element)

        updated_stats = Appom::ElementCache.cache_statistics
        expect(updated_stats[:hits]).to eq(1)
      end

      it 'handles exceptions gracefully' do
        allow(finder).to receive(:original_find_element).and_raise(StandardError, 'Element not found')

        expect do
          finder.find_element(:id, 'missing_element')
        end.to raise_error(StandardError, 'Element not found')

        # Should not cache failed lookups
        cache_stats = Appom::ElementCache.cache_statistics
        expect(cache_stats[:stores]).to eq(0)
      end
    end

    describe '#find_elements' do
      it 'uses cache for repeated multiple element lookups' do
        elements1 = finder.find_elements(:class, 'button')
        elements2 = finder.find_elements(:class, 'button')

        expect(elements2).to eq(elements1)

        cache_stats = Appom::ElementCache.cache_statistics
        expect(cache_stats[:hits]).to eq(1)
      end

      it 'caches arrays of elements' do
        elements = finder.find_elements(:tag_name, 'button')

        expect(elements).to be_an(Array)
        expect(elements.size).to eq(2)

        cache_stats = Appom::ElementCache.cache_statistics
        expect(cache_stats[:stores]).to eq(1)
      end
    end

    describe 'cache configuration' do
      it 'allows disabling cache per call' do
        allow(finder).to receive(:original_find_element).and_call_original

        # First call with cache
        finder.find_element(:id, 'test_button')

        # Second call without cache
        expect(finder).to receive(:original_find_element).with(:id, 'test_button')
        finder.find_element(:id, 'test_button', use_cache: false)
      end
    end
  end

  describe 'Global ElementCache module' do
    before { described_class.reset_cache }

    describe '.cache_element' do
      it 'stores element in global cache' do
        key = described_class.cache_element(:id, 'global_button', mock_element)

        expect(described_class.get_cached_element(key)).to eq(mock_element)
      end
    end

    describe '.get_cached_element' do
      it 'retrieves element from global cache' do
        key = described_class.cache_element(:id, 'global_button', mock_element)
        element = described_class.get_cached_element(key)

        expect(element).to eq(mock_element)
      end

      it 'returns nil for non-existent elements' do
        element = described_class.get_cached_element('nonexistent')

        expect(element).to be_nil
      end
    end

    describe '.cache_hit?' do
      it 'checks if element is cached' do
        key = described_class.cache_element(:id, 'check_button', mock_element)

        expect(described_class.cache_hit?(key)).to be true
        expect(described_class.cache_hit?('missing')).to be false
      end
    end

    describe '.cache_statistics' do
      it 'returns global cache statistics' do
        described_class.cache_element(:id, 'stats_button', mock_element)
        described_class.get_cached_element(described_class.cache.generate_key(:id, 'stats_button'))

        stats = described_class.cache_statistics

        expect(stats[:hits]).to eq(1)
        expect(stats[:stores]).to eq(1)
        expect(stats[:hit_rate]).to be > 0
      end
    end

    describe '.clear_cache' do
      it 'clears global cache' do
        described_class.cache_element(:id, 'clear_test', mock_element)

        expect(described_class.cache.size).to eq(1)

        described_class.clear_cache

        expect(described_class.cache.size).to eq(0)
      end
    end

    describe '.configure_cache' do
      it 'allows cache configuration' do
        described_class.configure_cache(max_size: 50, ttl: 600)

        expect(described_class.cache.max_size).to eq(50)
        expect(described_class.cache.ttl).to eq(600)
      end
    end
  end

  describe 'thread safety' do
    it 'handles concurrent access safely', :slow do
      threads = []
      elements = {}

      10.times do |i|
        threads << Thread.new do
          element = double("element_#{i}")
          key = described_class.cache_element(:id, "button_#{i}", element)
          elements[i] = { key: key, element: element }
        end
      end

      threads.each(&:join)

      # Verify all elements were cached
      expect(described_class.cache.size).to eq(10)

      # Verify retrieval
      elements.each_value do |data|
        cached_element = described_class.get_cached_element(data[:key])
        expect(cached_element).to eq(data[:element])
      end
    end

    context 'edge cases and missing coverage' do
      describe '#valid_element?' do
        it 'returns false for nil element' do
          expect(cache.send(:valid_element?, nil)).to be false
        end

        it 'returns true for element without displayed? method' do
          non_selenium_element = double('non_selenium_element')
          expect(cache.send(:valid_element?, non_selenium_element)).to be true
        end

        it 'returns false when element throws exception' do
          stale_element = double('stale_element')
          allow(stale_element).to receive(:displayed?).and_raise(StandardError)
          allow(stale_element).to receive(:respond_to?).with(:displayed?).and_return(true)

          expect(cache.send(:valid_element?, stale_element)).to be false
        end

        it 'returns true for valid element' do
          valid_element = double('valid_element')
          allow(valid_element).to receive(:displayed?).and_return(true)
          allow(valid_element).to receive(:respond_to?).with(:displayed?).and_return(true)

          expect(cache.send(:valid_element?, valid_element)).to be true
        end
      end

      describe '#get_or_find' do
        it 'returns cached element when available' do
          cached_element = double('cached_element')
          cache.store(:id, 'existing', cached_element)

          result = cache.get_or_find(:id, 'existing') { double('new_element') }
          expect(result).to eq(cached_element)
        end

        it 'finds and caches element when not in cache' do
          new_element = double('new_element')
          allow(new_element).to receive(:displayed?).and_return(true)
          allow(new_element).to receive(:respond_to?).with(:displayed?).and_return(true)

          result = cache.get_or_find(:id, 'missing') { new_element }

          expect(result).to eq(new_element)
          expect(cache.size).to eq(1)
        end

        it 'handles expired elements by finding new one' do
          expired_element = double('expired_element')
          new_element = double('new_element')
          allow(new_element).to receive(:displayed?).and_return(true)
          allow(new_element).to receive(:respond_to?).with(:displayed?).and_return(true)

          key = cache.store(:id, 'expiring', expired_element)

          # Manually set timestamp to past to simulate expiration
          cache.instance_variable_get(:@cache)[key][1] = Time.now - 400

          result = cache.get_or_find(:id, 'expiring') { new_element }
          expect(result).to eq(new_element)
        end
      end

      describe '#invalidate' do
        it 'removes element by find arguments' do
          element = double('element')
          cache.store(:id, 'to_invalidate', element)

          expect(cache.size).to eq(1)
          cache.invalidate(:id, 'to_invalidate')
          expect(cache.size).to eq(0)
        end

        it 'handles missing keys gracefully' do
          expect { cache.invalidate(:id, 'nonexistent') }.not_to raise_error
        end
      end

      describe '#reset' do
        it 'clears cache and resets statistics' do
          cache.store(:id, 'test1', double('element1'))
          cache.store(:id, 'test2', double('element2'))
          cache.get(cache.generate_key(:id, 'test1'))

          expect(cache.size).to eq(2)
          expect(cache.statistics[:hits]).to eq(1)

          cache.reset

          expect(cache.size).to eq(0)
          expect(cache.statistics[:hits]).to eq(0)
          expect(cache.statistics[:misses]).to eq(0)
          expect(cache.statistics[:stores]).to eq(0)
        end
      end

      describe '#generate_key' do
        it 'handles array arguments (old pattern)' do
          key1 = cache.generate_key([:id, 'test'])
          key2 = cache.generate_key(:id, 'test')

          expect(key1).to eq(key2)
        end

        it 'generates consistent keys for complex objects' do
          complex_args = [:xpath, '//div[@class="test"]', { timeout: 5 }]
          key1 = cache.generate_key(*complex_args)
          key2 = cache.generate_key(*complex_args)

          expect(key1).to eq(key2)
        end
      end

      describe 'eviction and cleanup' do
        it 'evicts LRU when no items exist' do
          empty_cache = Appom::ElementCache::Cache.new(max_size: 1)
          expect { empty_cache.send(:evict_lru) }.not_to raise_error
        end

        it 'properly handles cleanup when no expired items' do
          cache.store(:id, 'test1', double('element1'))
          cache.store(:id, 'test2', double('element2'))

          initial_size = cache.size
          cache.send(:cleanup_expired)

          expect(cache.size).to eq(initial_size)
        end

        it 'updates statistics during cleanup' do
          # Create cache with very short TTL
          short_ttl_cache = Appom::ElementCache::Cache.new(ttl: 0.01)
          short_ttl_cache.store(:id, 'expiring', double('element'))
          sleep(0.05) # Wait for expiration (ensure it's longer than TTL)
          short_ttl_cache.send(:cleanup_expired)
          expect(short_ttl_cache.statistics[:expirations]).to eq(1)
        end
      end

      describe 'statistics edge cases' do
        it 'calculates 0% hit rate with no operations' do
          expect(cache.statistics[:hit_rate]).to eq(0.0)
        end

        it 'handles hit rate calculation with only misses' do
          cache.get('nonexistent1')
          cache.get('nonexistent2')

          expect(cache.statistics[:hit_rate]).to eq(0.0)
        end

        it 'provides backward compatibility with stats method' do
          expect(cache.stats).to eq(cache.statistics)
        end
      end
    end

    # Temporarily commenting out CacheAwareFinder tests to focus on core coverage
    # These can be fixed separately
  end
end
