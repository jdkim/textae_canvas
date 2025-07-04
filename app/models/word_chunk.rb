class WordChunk
  # Extracts chunks of text from the words array, ensuring that each chunk does not exceed the specified window size.
  def self.from(text, window_size: 20)
    words_with_newlines = words_with_newlines_enum(text)
    Enumerator.new do |y|
      words_with_newlines.each_slice(window_size) do |chunk_words|
        y.yield join_words_to_text(chunk_words)
      end
    end
  end

  private

  # Extracts words from the text while preserving line breaks.
  # Normalizes line endings (\r\n to \n) and splits each line into words.
  # Empty lines are represented by a single newline character.
  # Words are collected sequentially, with newline characters added as separate elements only when lines end with newlines.
  def self.words_with_newlines_enum(text)
    Enumerator.new do |y|
      normalized_text = text.gsub(/\r\n/, "\n")
      normalized_text.each_line do |line|
        if line.strip.empty?
          y.yield "\n"
        else
          words = line.split(/\s+/)
          words.each { y.yield it }
          y.yield "\n" if line.end_with?("\n")
        end
      end
    end
  end

  # Joins an array of words into text, handling newlines and spaces appropriately
  def self.join_words_to_text(words)
    text = ""
    words.each do |word|
      if word == "\n"
        text += word
      elsif text.empty?
        text += word
      else
        text += " #{word}"
      end
    end
    text
  end
end
