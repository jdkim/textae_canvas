class SmartMultilingualTokenizer
  Token = Data.define(:token, :start_offset, :end_offset, :type)
  INDEX_NAME = "smart_multilingual"

  def initialize
    @client = Elasticsearch::Client.new(hosts: [ "localhost:9200" ])
  end

  # Tokenize text using Elasticsearch's analyze API
  def analyze(text)
    @client.indices.analyze(
      index: INDEX_NAME,
      body: { analyzer: "standard", text: text }
    )["tokens"].map do |token|
      Token.new token["token"].downcase,
                token["start_offset"],
                token["end_offset"],
                token["type"]
    end
  end
end
