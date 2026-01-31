# frozen_string_literal: true

require 'digest'

# Element caching system for Appom automation framework
# Provides intelligent element caching with TTL and LRU eviction policies
module Appom::ElementCache
  # Element caching to improve performance for frequently accessed elements
  class Cache
    include Appom::Logging

    attr_reader :max_size, :ttl

    def initialize(max_size: 100, ttl: 300)
      @cache = {}
      @access_times = {}
      @max_size = max_size
      @ttl = ttl # Time to live in seconds
      @stats = { hits: 0, misses: 0, evictions: 0, stores: 0, clears: 0, expirations: 0 }
    end

    # Store element in cache with strategy and value
    def store(strategy, value, element)
      cache_key = generate_key(strategy, value)
      store_in_cache(cache_key, element)
      @stats[:stores] += 1
      cache_key
    end

    # Get element from cache by key
    def get(cache_key) # rubocop:disable Metrics/AbcSize
      unless @cache.key?(cache_key)
        @stats[:misses] += 1
        return nil
      end

      element, timestamp = @cache[cache_key]

      # Check TTL
      if Time.now - timestamp > @ttl
        @cache.delete(cache_key)
        @access_times.delete(cache_key)
        @stats[:expirations] ||= 0
        @stats[:expirations] += 1
        @stats[:misses] += 1
        return nil
      end

      # Check if element is still valid
      unless valid_element?(element)
        @cache.delete(cache_key)
        @access_times.delete(cache_key)
        @stats[:misses] += 1
        return nil
      end

      # Update access time and refresh TTL
      current_time = Time.now
      @cache[cache_key] = [element, current_time]
      @access_times[cache_key] = current_time
      @stats[:hits] += 1
      element
    end

    # Check if key exists in cache
    def hit?(cache_key)
      return false unless @cache.key?(cache_key)

      element, timestamp = @cache[cache_key]

      # Check TTL without updating stats
      return false if Time.now - timestamp > @ttl

      valid_element?(element)
    end

    # Get cache size
    def size
      @cache.size
    end

    # Get element from cache or find and cache it
    def get_or_find(*find_args)
      cache_key = generate_key(find_args)

      if (cached_element = get(cache_key))
        log_debug("Cache HIT for #{find_args.join(', ')}")
        return cached_element
      end

      @stats[:misses] += 1
      log_debug("Cache MISS for #{find_args.join(', ')}")

      # Find element and cache it
      element = yield if block_given?
      store_in_cache(cache_key, element) if element
      element
    end

    # Invalidate specific element
    def invalidate(*find_args) # rubocop:disable Naming/PredicateMethod
      cache_key = generate_key(find_args)
      if @cache.delete(cache_key)
        @access_times.delete(cache_key)
        log_debug("Invalidated cache for #{find_args.join(', ')}")
        true
      else
        false
      end
    end

    # Clear all cached elements
    def clear
      @cache.clear
      @access_times.clear
      @stats[:clears] += 1
      log_info('Element cache cleared')
    end

    # Clear all cached elements and reset statistics
    def reset
      @cache.clear
      @access_times.clear
      @stats = { hits: 0, misses: 0, evictions: 0, stores: 0, clears: 0, expirations: 0 }
      log_info('Element cache reset')
    end

    # Get cache statistics
    def statistics
      {
        size: @cache.size,
        max_size: @max_size,
        hit_rate: calculate_hit_rate,
        **@stats,
      }
    end

    # Alias for backward compatibility
    def stats
      statistics
    end

    # Check if element is still valid (exists and is stale)
    def valid_element?(element)
      return false unless element
      return true unless element.respond_to?(:displayed?)

      begin
        # Try to access a property to check if element is stale
        element.displayed?
        true
      rescue StandardError
        # Element is stale or invalid
        false
      end
    end

    def generate_key(*args)
      # Handle both old and new calling patterns
      find_args = if args.length == 1 && args[0].is_a?(Array)
                    # Old pattern: generate_key([strategy, value])
                    args[0]
                  else
                    # New pattern: generate_key(strategy, value)
                    args
                  end

      # Create consistent cache key from find arguments
      Digest::MD5.hexdigest(find_args.to_s)
    end

    private

    def get_from_cache(cache_key)
      get(cache_key)
    end

    def store_in_cache(cache_key, element)
      # Clean up expired entries first
      cleanup_expired

      # Evict oldest if at capacity
      evict_lru if @cache.size >= @max_size

      timestamp = Time.now
      @cache[cache_key] = [element, timestamp]
      @access_times[cache_key] = timestamp

      log_debug("Cached element with key #{cache_key[0..8]}...")
    end

    def evict_lru
      # Remove least recently used item
      oldest_key = @access_times.min_by { |_k, v| v }&.first
      return unless oldest_key

      @cache.delete(oldest_key)
      @access_times.delete(oldest_key)
      @stats[:evictions] += 1
      log_debug('Evicted LRU element from cache')
    end

    def cleanup_expired # rubocop:disable Metrics/AbcSize
      current_time = Time.now
      expired_keys = []

      @cache.each do |key, (_element, timestamp)|
        expired_keys << key if current_time - timestamp > @ttl
      end

      expired_keys.each do |key|
        @cache.delete(key)
        @access_times.delete(key)
        @stats[:expirations] ||= 0
        @stats[:expirations] += 1
      end

      return unless expired_keys.any?

      log_debug("Cleaned up #{expired_keys.size} expired elements from cache")
    end

    def calculate_hit_rate
      total = @stats[:hits] + @stats[:misses]
      return 0.0 if total.zero?

      (@stats[:hits].to_f / total * 100).round(2)
    end
  end

  # Cache-aware element finder mixin
  module CacheAwareFinder
    def self.included(klass)
      # Don't alias if methods don't exist yet
      klass.send(:alias_method, :original_find_element, :find_element) if klass.method_defined?(:find_element)
      return unless klass.method_defined?(:find_elements)

      klass.send(:alias_method, :original_find_elements, :find_elements)
    end

    def find_element(strategy, locator, use_cache: true)
      # If not using cache or caching is disabled, use standard find method
      return _find_without_cache(strategy, locator) unless use_cache && begin
        Appom.cache_config[:enabled]
      rescue StandardError
        true
      end

      # Use global cache
      cache_key = Appom::ElementCache.cache.generate_key(strategy, locator)
      cached = Appom::ElementCache.cache.get(cache_key)

      return cached if cached

      element = _find_without_cache(strategy, locator)
      Appom::ElementCache.cache.store(strategy, locator, element) if element
      element
    end

    private

    def _find_without_cache(strategy, locator)
      # If original method doesn't exist, delegate to the page/driver
      if respond_to?(:original_find_element)
        original_find_element(strategy, locator)
      elsif respond_to?(:_find)
        _find(strategy, locator)
      else
        page.find_element(strategy, locator)
      end
    end

    public

    def find_elements(strategy, locator, use_cache: true) # rubocop:disable Metrics/CyclomaticComplexity
      # If original method doesn't exist, delegate to the page/driver
      return page.find_elements(strategy, locator) unless respond_to?(:original_find_elements)

      return original_find_elements(strategy, locator) unless use_cache && begin
        Appom.cache_config[:enabled]
      rescue StandardError
        true
      end

      # Use global cache
      cache_key = Appom::ElementCache.cache.generate_key(strategy, locator)
      cached = Appom::ElementCache.cache.get(cache_key)

      return cached if cached

      elements = original_find_elements(strategy, locator)
      Appom::ElementCache.cache.store(strategy, locator, elements) if elements
      elements
    end

    def element_cache
      @element_cache ||= Cache.new(
        max_size: Appom.cache_config[:max_size],
        ttl: Appom.cache_config[:ttl],
      )
    end

    # Clear cache for this finder
    def clear_element_cache
      element_cache.clear
    end

    # Get cache statistics
    def cache_stats
      element_cache.statistics
    end
  end

  # Global cache instance and module methods
  @global_cache = nil

  module_function

  def cache
    @global_cache || (@cache ||= Cache.new)
  end

  def clear_cache
    cache.clear
  end

  def reset_cache
    cache.reset
  end

  def cache_element(strategy, value, element)
    cache.store(strategy, value, element)
  end

  def get_cached_element(key)
    cache.get(key)
  end

  def cache_hit?(key)
    cache.hit?(key)
  end

  def cache_statistics
    cache.statistics
  end

  def configure_cache(**)
    @global_cache = Cache.new(**)
  end
end

# Configuration for element caching
module Appom
  class << self
    attr_accessor :cache_config

    def configure_cache(max_size: 50, ttl: 30, enabled: true)
      @cache_config = {
        max_size: max_size,
        ttl: ttl,
        enabled: enabled,
      }
    end
  end

  # Default cache configuration
  @cache_config = {
    max_size: 50,
    ttl: 30,
    enabled: true,
  }
end
