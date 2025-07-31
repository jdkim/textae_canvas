require "json"
require "ostruct"

# Main hub class for collection format conversion
class DataSlime
  attr_reader :data

  def initialize(data)
    @data = normalize_data(data)
  end

  # Convert to symbol keys (deep)
  def to_symbol_keys
    deep_transform_keys(@data) { |key| key.to_sym }
  end

  # Convert to string keys (deep)
  def to_string_keys
    deep_transform_keys(@data) { |key| key.to_s }
  end

  # Convert to JSON string
  def to_json_string(pretty: false)
    json_ready = deep_transform_keys(@data) { |key| key.to_s }
    pretty ? JSON.pretty_generate(json_ready) : JSON.generate(json_ready)
  end

  # Convert to parsed JSON (hash with string keys)
  def to_json_hash
    JSON.parse(to_json_string)
  end

  # Convert to indifferent access (works with both string and symbol keys)
  def to_indifferent_access
    IndifferentHash.new(@data)
  end

  # Convert to OpenStruct for dot notation access
  def to_open_struct
    deep_to_open_struct(@data)
  end

  # Convert to query string format
  def to_query_string
    flatten_hash(@data).map { |k, v| "#{k}=#{v}" }.join("&")
  end

  # Convert to dot notation hash (flattened with dots)
  def to_dot_notation
    flatten_hash(@data, ".")
  end

  # Convert to underscore notation (flattened with underscores)
  def to_underscore_notation
    flatten_hash(@data, "_")
  end

  # Convert to nested array format [[key, value], [key2, value2]]
  def to_nested_array
    flatten_hash(@data).to_a
  end

  # Convert to path-value pairs
  def to_path_values
    result = {}
    flatten_hash(@data).each do |path, value|
      result[path.split(".").map(&:to_sym)] = value
    end
    result
  end

  # Raw data access
  def to_hash
    @data.dup
  end

  # Direct access methods - makes DataSlime behave like a hash
  def [](key)
    indifferent_data[key]
  end

  def []=(key, value)
    @data = {} unless @data.is_a?(Hash)
    indifferent_data[key] = value
  end

  def key?(key)
    indifferent_data.key?(key)
  end

  def keys
    @data.is_a?(Hash) ? @data.keys : []
  end

  def values
    @data.is_a?(Hash) ? @data.values : []
  end

  def dig(*keys)
    indifferent_data.dig(*keys)
  end

  def fetch(key, default = nil)
    indifferent_data.fetch(key, default)
  end

  def delete(key)
    return nil unless @data.is_a?(Hash)
    indifferent_data.delete(key)
  end

  def merge(other_hash)
    DataSlime.new(indifferent_data.merge(other_hash))
  end

  def merge!(other_hash)
    @data = indifferent_data.merge(other_hash)
    self
  end

  private

  def indifferent_data
    @indifferent_data ||= IndifferentHash.new(@data.is_a?(Hash) ? @data : {})
  end

  def normalize_data(data)
    case data
    when String
      begin
        JSON.parse(data)
      rescue JSON::ParserError
        data
      end
    else
      data
    end
  end

  def deep_transform_keys(object, &block)
    case object
    when Hash
      object.each_with_object({}) do |(key, value), result|
        result[yield(key)] = deep_transform_keys(value, &block)
      end
    when Array
      object.map { |item| deep_transform_keys(item, &block) }
    else
      object
    end
  end

  def deep_to_open_struct(object)
    case object
    when Hash
      OpenStruct.new(object.transform_values { |v| deep_to_open_struct(v) })
    when Array
      object.map { |item| deep_to_open_struct(item) }
    else
      object
    end
  end

  def flatten_hash(hash, separator = ".")
    hash.each_with_object({}) do |(k, v), h|
      if v.is_a?(Hash)
        flatten_hash(v, separator).map do |h_k, h_v|
          h["#{k}#{separator}#{h_k}"] = h_v
        end
      else
        h[k.to_s] = v
      end
    end
  end
end