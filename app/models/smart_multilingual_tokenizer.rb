class SmartMultilingualTokenizer
  Token = Data.define(:token, :start_offset, :end_offset, :type)
  INDEX_NAME = "smart_multilingual"

  def initialize
    @client = Elasticsearch::Client.new(hosts: [ "localhost:9200" ])
  end

  # Detect language and tokenize text using Elasticsearch analyzer
  def analyze(text)
    tokenize_with_standard_analyzer(text)
  end

  private

  # Tokenize text using Elasticsearch's analyze API
  def tokenize_with_standard_analyzer(text)
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
