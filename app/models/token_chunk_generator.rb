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

  # トークン列を文単位で分割する（original_textから文区切り位置を検出）
  def split_tokens_by_sentence(tokens)
    sentences = []
    sentence_boundaries = []
    sentence_end_regex = /[。．.！？!?]/
    # 文末記号でoriginal_textを分割し、各文のoffset範囲を取得
    start_offset = 0
    @original_text.scan(/.*?[。．.！？!?]/m) do |sentence|
      end_offset = start_offset + sentence.length
      sentence_boundaries << [ start_offset, end_offset ]
      start_offset = end_offset
    end
    # 残りの文（文末記号がない場合）
    if start_offset < @original_text.length
      sentence_boundaries << [ start_offset, @original_text.length ]
    end
    # 各文範囲に含まれるtokensをグループ化し、文末記号はSmartMultilingualTokenizer::Tokenで追加
    sentence_boundaries.each do |begin_off, end_off|
      sentence_tokens = tokens.select { |token| token.start_offset >= begin_off && token.end_offset <= end_off }
      sentence_text = @original_text[begin_off...end_off]
      if sentence_text =~ sentence_end_regex
        punct_offset = end_off - 1
        punct_text = @original_text[punct_offset]
        unless sentence_tokens.any? { |t| t.start_offset == punct_offset }
          # SmartMultilingualTokenizer::Tokenで文末記号トークンを生成
          punct_token = SmartMultilingualTokenizer::Token.new(punct_text, punct_offset, end_off)
          sentence_tokens << punct_token
        end
      end
      sentences << sentence_tokens unless sentence_tokens.empty?
    end
    sentences
  end

  # Main loop for generating token chunks
  def generate_chunks
    return [] if @tokens.empty?
    chunks = []
    sentences = []
    sentence_boundaries = []
    sentence_end_regex = /[。．.！？!?]/
    # original_textから文区切り位置を検出
    start_offset = 0
    @original_text.scan(/.*?[。．.！？!?]/m) do |sentence|
      end_offset = start_offset + sentence.length
      sentence_boundaries << [ start_offset, end_offset ]
      start_offset = end_offset
    end
    # 残りの文（文末記号がない場合）
    if start_offset < @original_text.length
      sentence_boundaries << [ start_offset, @original_text.length ]
    end
    # 各文範囲に含まれるtokensをグループ化し、文末トークンにピリオドや句点を含める
    sentence_boundaries.each do |begin_off, end_off|
      sentence_tokens = @tokens.select { |token| token.start_offset >= begin_off && token.end_offset <= end_off }
      # 文末記号がoriginal_textに含まれていれば、その部分のトークンも追加
      sentence_text = @original_text[begin_off...end_off]
      punct_token = nil
      if sentence_text =~ sentence_end_regex
        punct_offset = end_off - 1
        punct_text = @original_text[punct_offset]
        # トークン化されていない場合は自作トークンとして追加
        unless sentence_tokens.any? { |t| t.start_offset == punct_offset }
          punct_token = SmartMultilingualTokenizer::Token.new(punct_text, punct_offset, punct_offset + 1, "punctuation")
        end
      end
      sentence_tokens << punct_token if punct_token
      sentences << sentence_tokens unless sentence_tokens.empty?
    end
    # チャンク化処理
    i = 0
    while i < sentences.size
      chunk_tokens = []
      chunk_size = 0
      # @window_sizeに収まるだけ文を追加
      while i < sentences.size && (chunk_size + sentences[i].size) <= @window_size
        chunk_tokens.concat(sentences[i])
        chunk_size += sentences[i].size
        i += 1
      end
      # 1文がwindow_sizeを超える場合はその文だけでチャンク化
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
