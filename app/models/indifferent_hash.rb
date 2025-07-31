# Optimized IndifferentHash class for accessing with both string and symbol keys
class IndifferentHash < Hash
  def initialize(hash = {})
    super()
    # Pre-allocate capacity for better performance
    if hash.respond_to?(:size) && hash.size > 0
      # Use internal method to avoid overhead if available
      self.rehash if respond_to?(:rehash, true)
    end
    update(hash)
  end

  def [](key)
    # Fast path: try the key as-is first (most common case)
    result = super(key)
    return result unless result.nil? && !has_key?(key)

    # Slow path: convert key and try again
    super(convert_key(key))
  end

  def []=(key, value)
    super(convert_key(key), convert_value(value))
  end

  def key?(key)
    # Fast path: check original key first
    return true if super(key)
    # Slow path: convert and check
    super(convert_key(key))
  end

  def has_key?(key)
    key?(key)
  end

  def fetch(key, *args)
    # Fast path: try original key first
    if super(key) { :__not_found__ } != :__not_found__
      return super(key, *args)
    end
    # Slow path: convert key
    super(convert_key(key), *args)
  end

  def delete(key)
    # Try both variants to ensure deletion
    result = super(key)
    converted = convert_key(key)
    result || super(converted) if converted != key
    result
  end

  def update(hash)
    if hash.is_a?(IndifferentHash)
      # Fast path for same type
      super(hash)
    else
      # Batch update for better performance
      hash.each_pair { |key, value| self[key] = value }
    end
    self
  end

  alias_method :merge!, :update

  def merge(hash)
    # Use clone instead of dup for better performance with frozen objects
    result = clone
    result.update(hash)
  end

  def dig(key, *rest)
    value = self[key]
    if value.nil? || rest.empty?
      value
    elsif value.respond_to?(:dig)
      value.dig(*rest)
    end
  end

  # Add iteration optimization
  def each
    return enum_for(:each) unless block_given?
    super { |k, v| yield(k, v) }
  end

  private

  # Cache converted keys to avoid repeated conversion
  def convert_key(key)
    case key
    when Symbol
      key.to_s
    when String
      key
    else
      key.to_s
    end
  end

  def convert_value(value)
    case value
    when IndifferentHash
      value
    when Hash
      IndifferentHash.new(value)
    when Array
      # Use map! if possible for in-place modification
      value.map { |item| convert_value_item(item) }
    else
      value
    end
  end

  def convert_value_item(item)
    case item
    when Hash
      item.is_a?(IndifferentHash) ? item : IndifferentHash.new(item)
    else
      item
    end
  end
end