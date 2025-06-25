class AnnotationConverter
  JSON2INLINE_API = URI("https://pubannotation.org/conversions/json2inline").freeze

  def to_inline(json)
    SimpleInlineTextAnnotation.generate(JSON.parse(json))
  end
end
