module TokenChunk
  class WindowSizeCalculator
    # Determine window_size unit by language
    # English: token count, Japanese/Korean: character count
    def self.calculate(language, tokens)
      case language
      when "ja", "ko"
        # Total character count
        tokens.map { |t| t.end_offset - t.start_offset }.sum
      else
        # Token count
        tokens.size
      end
    end
  end
end
