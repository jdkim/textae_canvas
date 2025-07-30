class TokenChunk
  # Initialize the tokenizer for multilingual text
  def initialize
    @tokenizer = SmartMultilingualTokenizer.new
  end

  # Generate token chunks from JSON data using the specified window size
  def from(annotations, window_size: 20)
    # window_sizeが不正ならArgumentErrorを投げる
    raise ArgumentError, "window_size must be greater than 0" if window_size <= 0

    # Analyze the text
    tokens = @tokenizer.analyze annotations["text"]

    # Generate chunks using the TokenChunkGenerator
    TokenChunkGenerator.new(annotations,
                            tokens,
                            window_size)
                       .generate_chunks
  end
end
