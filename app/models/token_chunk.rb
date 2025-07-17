class TokenChunk
  # Initialize Elasticsearch client and tokenizer
  def initialize
    @tokenizer = SmartMultilingualTokenizer.new
  end

  # Generate token chunks from JSON data with a specified window size
  def from(json_data, window_size: 20)
    original_text = json_data["text"]
    original_denotations = json_data["denotations"] || []
    original_relations = json_data["relations"] || []

    return [] if window_size <= 0

    response = @tokenizer.analyze_multilingual_text(original_text)
    language = response.language

    TokenChunkGenerator.new(language).generate_chunks(
      original_text,
      original_denotations,
      original_relations,
      response.tokens,
      window_size
    )
  end
end
