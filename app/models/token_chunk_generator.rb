class TokenChunkGenerator
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
    i = 0
    while i < @tokens.size
      # Select tokens for the current window
      window_tokens = @tokens[i, @window_size]
      break if window_tokens.nil? || window_tokens.empty?

      # Determine chunk range and actual tokens
      chunk_begin, chunk_end, resolved_window_tokens = resolve_chunk_range_and_tokens window_tokens

      if resolved_window_tokens.any?
        # Build chunk data (text, denotations, relations)
        chunk_data = @slicer.annotation_in chunk_begin..chunk_end
        chunks << chunk_data

        i = next_chunk_begin_index(i, chunk_end)
      else
        i = i + 1
      end
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
      actual_tokens = actual_tokens.first shrink_index
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
    @text = text

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

  def language
    @language ||= LanguageDetectable.detect_language(@text)
  end

  # Find if any denotation crosses the chunk boundary
  def find_denotation_crossing_index(chunk_begin, chunk_end, window_tokens)
    return nil if window_tokens.empty?

    @original_denotations.each do |d|
      d_begin = d["span"]["begin"]
      d_end = d["span"]["end"]
      # If denotation starts in chunk but ends outside, find where to shrink
      if chunk_begin <= d_begin && d_begin < chunk_end && chunk_end < d_end
        found_index = window_tokens.find_index { |t| d_begin <= t[:start_offset] }
        return found_index if found_index && found_index > 0
      end
    end
    nil
  end

  # Decide window unit: char count for CJK, token count otherwise
  def window_unit(word_count, char_count)
    case language
    when "ja", "ko"
      char_count
    else
      word_count
    end
  end
end
