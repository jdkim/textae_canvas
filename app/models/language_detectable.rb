module LanguageDetectable
  def self.detect_language(text)
    return "unknown" if text.nil? || text.empty?
    lang = CLD3::NNetLanguageIdentifier.new(0, 400).find_language(text)&.language
    case lang
    when :ja, :ko, :en
      lang.to_s
    else
      "unknown"
    end
  end
end
