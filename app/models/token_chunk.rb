class TokenChunk
  # Initialize the tokenizer for multilingual text
  def initialize
    @tokenizer = SmartMultilingualTokenizer.new
  end

  # Generate token chunks from JSON data using the specified window size
  def from(json_data, window_size: 20)
    original_text = json_data["text"]
    original_denotations = json_data["denotations"] || []
    original_relations = json_data["relations"] || []

    # Return empty array if window size is invalid
    return [] if window_size <= 0

    # Analyze the text and detect language
    response = @tokenizer.analyze_multilingual_text original_text
    language = response.language

    # Generate chunks using the TokenChunkGenerator
    TokenChunkGenerator.new(language,
                            original_text,
                            original_denotations,
                            original_relations,
                            window_size,
                            response.tokens)
                       .generate_chunks
  end
end
