module TokenChunk
  Token = Data.define(:token, :start_offset, :end_offset, :type)

  # Generate token chunks from JSON data using the specified window size
  def self.from(annotations, window_size: 20)
    # window_sizeが不正ならArgumentErrorを投げる
    raise ArgumentError, "window_size must be greater than 0" if window_size <= 0

    # Analyze the text
    tokens = SmartMultilingualTokenizer.new.analyze annotations["text"]

    # Generate chunks using the TokenChunkGenerator
    TokenChunkGenerator.new(annotations,
                            tokens,
                            window_size)
                       .generate_chunks
  end
end
