class TokenChunkGenerator
  def initialize(original_text, original_denotations, original_relations, language, tokens, window_size)
    @language = language
    @original_text = original_text
    @original_denotations = original_denotations || []
    @original_relations = original_relations || []
    @window_size = window_size
    @tokens = tokens || []
  end

  # Main loop for generating token chunks
  def generate_chunks
    return [] if @tokens.empty?
    slicer = AnnotationSlicer.new(@original_text, @original_denotations, @original_relations)
    chunks = []
    i = 0
    while i < @tokens.size
      # Select tokens for the current window
      window_tokens = @tokens[i, @window_size]
      break if window_tokens.nil? || window_tokens.empty?

      # Determine chunk range and actual tokens
      chunk_begin, chunk_end, resolved_window_tokens = resolve_chunk_range_and_tokens window_tokens

      # Decide next start index for chunking
      next_i = resolved_window_tokens.any? ? next_chunk_begin_index(i, chunk_end) : i + 1

      if resolved_window_tokens.empty?
        i = next_i
        next
      end

      # Build chunk data (text, denotations, relations)
      chunk_data = slicer.annotation_in chunk_begin..chunk_end
      chunks << chunk_data
      i = next_i
    end
    chunks
  end

  private

  # Decide chunk start/end and which tokens to include
  def resolve_chunk_range_and_tokens(window_tokens)
    chunk_begin = window_tokens.first.start_offset

    extended_chunk_end = find_chunk_end_boundary @original_text, chunk_begin

    actual_tokens = @tokens.select { |token| chunk_begin <= token.start_offset && token.end_offset <= extended_chunk_end }

    if (shrink_index = find_denotation_crossing_index(chunk_begin, extended_chunk_end, actual_tokens))&.positive?
      actual_tokens = actual_tokens.first(shrink_index)
      extended_chunk_end = actual_tokens.last.end_offset if actual_tokens.any?
    end

    [ chunk_begin, extended_chunk_end, actual_tokens ]
  end

  # Calculate the next index to start chunking from
  def next_chunk_begin_index(i, chunk_end)
    tokens_consumed = @tokens[i..].take_while { it.end_offset <= chunk_end }.size
    i + [ tokens_consumed, 1 ].max
  end

  # Find the end of the chunk by sentence boundary or punctuation
  def find_chunk_end_boundary(text, current_end)
    last_found_end = current_end
    begin_index = current_end

    while current_end < text.length
      char = text[current_end]
      # Check for sentence-ending punctuation
      if char =~ /[\.。！？!?]/
        last_found_end = current_end + 1
        current_end += 1
      end
      current_end += 1

      # Check if window size is exceeded
      word_count = text[begin_index..current_end].split(" ").length
      char_count = current_end - begin_index
      if window_unit(word_count, char_count) > @window_size
        return last_found_end
      end
    end
    current_end
  end


  # Find if any denotation crosses the chunk boundary
  def find_denotation_crossing_index(chunk_begin, chunk_end, window_tokens)
    return nil if window_tokens.empty?

    @original_denotations.each do |d|
      d_begin = d["span"]["begin"]
      d_end = d["span"]["end"]
      # If denotation starts in chunk but ends outside, find where to shrink
      if d_begin >= chunk_begin && d_begin < chunk_end && d_end > chunk_end
        found_index = window_tokens.find_index { |t| t[:start_offset] >= d_begin }
        return found_index if found_index && found_index > 0
      end
    end
    nil
  end

  # Decide window unit: char count for CJK, token count otherwise
  def window_unit(word_count, char_count)
    case @language
    when "ja", "ko"
      char_count
    else
      word_count
    end
  end
end
