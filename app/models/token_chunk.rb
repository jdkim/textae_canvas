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

    # window_sizeが不正ならArgumentErrorを投げる
    raise ArgumentError, "window_size must be greater than 0" if window_size <= 0

    # Analyze the text and detect language
    response = @tokenizer.analyze original_text
    language = response.language

    # Generate chunks using the TokenChunkGenerator
    TokenChunkGenerator.new(original_text,
                            original_denotations,
                            original_relations,
                            language,
                            response.tokens,
                            window_size)
                       .generate_chunks
  end
end
