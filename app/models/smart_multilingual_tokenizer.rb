class SmartMultilingualTokenizer
  Response = Data.define(:token, :start_offset, :end_offset, :type)
  def initialize(client)
    @client = client
    @index_name = "smart_multilingual"
  end

  # Analyze text: detect language and tokenize using Elasticsearch analyzer
  def analyze_multilingual_text(text)
    {
      language: detect_language(text),
      tokens: tokenize_with_standard_analyzer(text)
    }
  end

  # Analyze an array of texts with language detection and tokenization
  def analyze_mixed_content(texts)
    texts.map do |text|
      result = analyze_multilingual_text(text)
      {
        original: text,
        detected_language: result[:language],
        tokens: result[:tokens],
        token_count: result[:tokens].size
      }
    end
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
      index: @index_name,
      body: { analyzer: "standard", text: text }
    )["tokens"].map do |token|
      Response.new(token["token"].downcase,
                  token["start_offset"],
                  token["end_offset"],
                  token["type"])
    end
  end
end
