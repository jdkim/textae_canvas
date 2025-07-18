class SmartMultilingualTokenizer
  Token = Data.define(:token, :start_offset, :end_offset, :type)
  Analyzed = Data.define(:language, :tokens)
  INDEX_NAME = "smart_multilingual"

  def initialize
    @client = Elasticsearch::Client.new(hosts: [ "localhost:9200" ])
  end

  # Analyze text: detect language and tokenize using Elasticsearch analyzer
  def analyze_multilingual_text(text)
    Analyzed.new(detect_language(text),
                 tokenize_with_standard_analyzer(text))
  end

  private

  # Detect language using CLD3 (refactored to be more idiomatic Ruby)
  def detect_language(text)
    lang = CLD3::NNetLanguageIdentifier.new(0, 400).find_language(text)&.language
    { ja: "ja", ko: "ko", en: "en" }[lang] || "unknown"
  end

  # Tokenize text using Elasticsearch's analyze API
  def tokenize_with_standard_analyzer(text)
    @client.indices.analyze(
      index: INDEX_NAME,
      body: { analyzer: "standard", text: text }
    )["tokens"].map do |token|
      Token.new(token["token"].downcase,
                token["start_offset"],
                token["end_offset"],
                token["type"])
    end
  end
end
