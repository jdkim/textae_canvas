class WindowSizeCalculator
  # window_sizeの単位を言語ごとに判定
  # 英語: トークン数, 日本語・韓国語: 文字数
  def self.calculate(language, tokens)
    case language
    when "ja", "ko"
      # 文字数合計
      tokens.map { |t| t.end_offset - t.start_offset }.sum
    else
      # トークン数
      tokens.size
    end
  end
end

