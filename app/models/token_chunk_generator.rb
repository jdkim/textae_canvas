class TokenChunkGenerator
  SENTENCE_BOUNDARY_PATTERN = "[。．.！？!?]"

  include LanguageDetectable
  def initialize(annotation, tokens, window_size)
    @original_text = annotation["text"]
    @original_denotations = annotation["denotations"] || []
    @original_relations = annotation["relations"] || []
    @tokens = tokens || []
    @window_size = window_size
    @slicer = AnnotationSlicer.new(annotation)
  end

  # Main loop for generating token chunks
  def generate_chunks
    return [] if @tokens.empty?

    chunks = []
    # Chunking process
    i = 0
    while i < sentences.size
      chunk_tokens = []
      # Add as many sentences as fit in @window_size
      while i < sentences.size
        @text = sentences[i].first&.token
        size = WindowSizeCalculator.calculate(language, chunk_tokens + sentences[i])
        if size > @window_size
          break
        end
        chunk_tokens.concat(sentences[i])
        i += 1
      end
      # If a single sentence exceeds window_size, chunk only that sentence
      if chunk_tokens.empty? && i < sentences.size
        chunk_tokens = sentences[i]
        i += 1
      end
      next if chunk_tokens.empty?
      chunk_begin = chunk_tokens.first.start_offset
      chunk_end = chunk_tokens.last.end_offset
      chunk_data = @slicer.annotation_in chunk_begin..chunk_end
      chunks << chunk_data
    end

    chunks
  end

  private

  def sentences
    return @sentences if @sentences
    sentence_boundaries = []
    sentence_end_regex = /#{SENTENCE_BOUNDARY_PATTERN}/
    # Detect sentence boundaries from original_text
    start_offset = 0
    @original_text.scan(/.*?#{SENTENCE_BOUNDARY_PATTERN}/m) do |sentence|
      end_offset = start_offset + sentence.length
      sentence_boundaries << [ start_offset, end_offset ]
      start_offset = end_offset
    end
    # Remaining sentence (if no sentence-ending punctuation)
    if start_offset < @original_text.length
      sentence_boundaries << [ start_offset, @original_text.length ]
    end
    # Group tokens contained in each sentence range, include period or punctuation in sentence-end token
    @sentences ||= sentence_boundaries.each_with_object([]) do |(begin_offset, end_offset), ext_sentences|
      sentence_tokens = @tokens.select { |token| token.start_offset >= begin_offset && token.end_offset <= end_offset }
      # If sentence-ending punctuation is in original_text, add token for that part
      sentence_text = @original_text[begin_offset...end_offset]
      punct_token = nil
      if sentence_text =~ sentence_end_regex
        punct_offset = end_offset - 1
        punct_text = @original_text[punct_offset]
        # If not tokenized, add as custom token
        unless sentence_tokens.any? { |t| t.start_offset == punct_offset }
          punct_token = SmartMultilingualTokenizer::Token.new(punct_text, punct_offset, punct_offset + 1, "punctuation")
        end
      end
      sentence_tokens << punct_token if punct_token
      ext_sentences << sentence_tokens unless sentence_tokens.empty?
    end
  end

  def language
    @language ||= LanguageDetectable.detect_language(@text)
  end
end
