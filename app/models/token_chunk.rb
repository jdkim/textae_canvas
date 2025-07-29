class TokenChunk
  # Initialize the tokenizer for multilingual text
  def initialize
    @tokenizer = SmartMultilingualTokenizer.new
  end

  # Generate token chunks from JSON data using the specified window size
  def from(annotations, window_size: 20)
    original_text = annotations["text"]
    original_denotations = annotations["denotations"] || []
    original_relations = annotations["relations"] || []

    # window_sizeが不正ならArgumentErrorを投げる
    raise ArgumentError, "window_size must be greater than 0" if window_size <= 0

    # Analyze the text and detect language
    response = @tokenizer.analyze original_text

    # Generate chunks using the TokenChunkGenerator
    TokenChunkGenerator.new(annotations,
                            response,
                            window_size)
                       .generate_chunks
  end
end
