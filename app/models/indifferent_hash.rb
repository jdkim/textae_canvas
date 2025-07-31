# IndifferentHash class for accessing with both string and symbol keys
class IndifferentHash < Hash
  def initialize(hash = {})
    super()
    update(hash)
  end

  def [](key)
    super(convert_key(key))
  end

  def []=(key, value)
    super(convert_key(key), convert_value(value))
  end

  def key?(key)
    super(convert_key(key))
  end

  def has_key?(key)
    super(convert_key(key))
  end

  def fetch(key, *args)
    super(convert_key(key), *args)
  end

  def delete(key)
    super(convert_key(key))
  end

  def update(hash)
    hash.each_pair { |key, value| self[key] = value }
    self
  end

  alias_method :merge!, :update

  def merge(hash)
    dup.update(hash)
  end

  def dig(key, *rest)
    value = self[key]
    if value.nil? || rest.empty?
      value
    elsif value.respond_to?(:dig)
      value.dig(*rest)
    end
  end

  private

  def convert_key(key)
    key.is_a?(Symbol) ? key.to_s : key
  end

  def convert_value(value)
    case value
    when Hash
      value.is_a?(IndifferentHash) ? value : IndifferentHash.new(value)
    when Array
      value.map { |item| convert_value(item) }
    else
      value
    end
  end
end
