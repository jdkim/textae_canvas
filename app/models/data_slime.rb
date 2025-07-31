# Optimized main hub class for collection format conversion
class DataSlime
  attr_reader :data

  def initialize(data)
    @data = normalize_data(data)
    @indifferent_data = nil  # Lazy initialization
  end

  # Convert to symbol keys (deep) - optimized
  def to_symbol_keys
    @symbol_keys_cache ||= deep_transform_keys(@data) { |key| key.to_sym }
  end

  # Convert to string keys (deep) - optimized
  def to_string_keys
    @string_keys_cache ||= deep_transform_keys(@data) { |key| key.to_s }
  end

  # Convert to JSON string - optimized
  def to_json_string(pretty: false)
    json_data = @string_keys_cache || to_string_keys
    pretty ? JSON.pretty_generate(json_data) : JSON.generate(json_data)
  end

  # Convert to parsed JSON (hash with string keys) - optimized
  def to_json_hash
    @json_hash_cache ||= JSON.parse(to_json_string)
  end

  # Convert to indifferent access (works with both string and symbol keys)
  def to_indifferent_access
    indifferent_data
  end

  # Convert to OpenStruct for dot notation access - optimized with caching
  def to_open_struct
    @open_struct_cache ||= deep_to_open_struct(@data)
  end

  # Convert to query string format - optimized
  def to_query_string
    @query_string_cache ||= begin
                              flattened = flatten_hash(@data)
                              if flattened.empty?
                                ""
                              else
                                flattened.map { |k, v| "#{k}=#{v}" }.join("&")
                              end
                            end
  end

  # Convert to dot notation hash (flattened with dots) - optimized
  def to_dot_notation
    @dot_notation_cache ||= flatten_hash(@data, ".")
  end

  # Convert to underscore notation (flattened with underscores) - optimized
  def to_underscore_notation
    @underscore_notation_cache ||= flatten_hash(@data, "_")
  end

  # Convert to nested array format [[key, value], [key2, value2]] - optimized
  def to_nested_array
    @nested_array_cache ||= flatten_hash(@data).to_a
  end

  # Convert to path-value pairs - optimized
  def to_path_values
    @path_values_cache ||= begin
                             result = {}
                             flatten_hash(@data).each do |path, value|
                               result[path.split(".").map(&:to_sym)] = value
                             end
                             result
                           end
  end

  # Raw data access
  def to_hash
    @data.is_a?(Hash) ? @data.dup : @data
  end

  # Direct access methods - makes DataSlime behave like a hash
  def [](key)
    indifferent_data[key]
  end

  def []=(key, value)
    ensure_hash_data
    clear_caches  # Clear caches when data changes
    indifferent_data[key] = value
  end

  def key?(key)
    return false unless @data.is_a?(Hash)
    indifferent_data.key?(key)
  end

  def keys
    @data.is_a?(Hash) ? @data.keys : []
  end

  def values
    @data.is_a?(Hash) ? @data.values : []
  end

  def dig(*keys)
    return nil unless @data.is_a?(Hash)
    indifferent_data.dig(*keys)
  end

  def fetch(key, default = nil)
    indifferent_data.fetch(key, default)
  end

  def delete(key)
    return nil unless @data.is_a?(Hash)
    clear_caches  # Clear caches when data changes
    indifferent_data.delete(key)
  end

  def merge(other_hash)
    DataSlime.new(indifferent_data.merge(other_hash))
  end

  def merge!(other_hash)
    ensure_hash_data
    clear_caches  # Clear caches when data changes
    @data = indifferent_data.merge(other_hash)
    @indifferent_data = nil  # Reset indifferent data
    self
  end

  # Add size and empty? methods for better usability
  def size
    @data.is_a?(Hash) ? @data.size : 0
  end

  def empty?
    @data.nil? || (@data.is_a?(Hash) && @data.empty?)
  end

  private

  def indifferent_data
    @indifferent_data ||= IndifferentHash.new(@data.is_a?(Hash) ? @data : {})
  end

  def ensure_hash_data
    @data = {} unless @data.is_a?(Hash)
  end

  def clear_caches
    @symbol_keys_cache = nil
    @string_keys_cache = nil
    @json_hash_cache = nil
    @open_struct_cache = nil
    @query_string_cache = nil
    @dot_notation_cache = nil
    @underscore_notation_cache = nil
    @nested_array_cache = nil
    @path_values_cache = nil
  end

  def normalize_data(data)
    case data
    when String
      return data if data.empty?
      begin
        JSON.parse(data)
      rescue JSON::ParserError
        data
      end
    else
      data
    end
  end

  # Optimized deep transformation with early returns
  def deep_transform_keys(object, &block)
    case object
    when Hash
      return object if object.empty?
      object.each_with_object({}) do |(key, value), result|
        new_key = yield(key)
        result[new_key] = deep_transform_keys(value, &block)
      end
    when Array
      return object if object.empty?
      object.map { |item| deep_transform_keys(item, &block) }
    else
      object
    end
  end

  # Optimized OpenStruct conversion
  def deep_to_open_struct(object)
    case object
    when Hash
      return OpenStruct.new if object.empty?
      OpenStruct.new(object.transform_values { |v| deep_to_open_struct(v) })
    when Array
      return [] if object.empty?
      object.map { |item| deep_to_open_struct(item) }
    else
      object
    end
  end

  # Optimized hash flattening with better performance
  def flatten_hash(hash, separator = ".")
    return {} unless hash.is_a?(Hash)
    return {} if hash.empty?

    result = {}
    stack = [ [ hash, "" ] ]

    until stack.empty?
      current_hash, prefix = stack.pop

      current_hash.each do |k, v|
        key = prefix.empty? ? k.to_s : "#{prefix}#{separator}#{k}"

        if v.is_a?(Hash) && !v.empty?
          stack.push([ v, key ])
        else
          result[key] = v
        end
      end
    end

    result
  end
end
