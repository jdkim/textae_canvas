class AnnotationSlicer
  def initialize(annotation, strict_mode: false)
    @text = annotation["text"]
    @denotations = annotation["denotations"] || []
    @relations = annotation["relations"] || []
    @strict_mode = strict_mode
  end

  def annotation_in(range)
    {
      "text" => @text[range.begin...range.end],
      "denotations" => denotations_in(range),
      "relations" => relations_of(denotations_in range)
    }
  end

  private

  def denotations_in(range)
    raise ArgumentError, "range includes nil" if range.begin.nil? || range.end.nil?

    @denotations.each_with_object([]) do |denotation, arr|
      begin_index = denotation["span"]["begin"]
      end_index = denotation["span"]["end"]
      if range.cover?(begin_index..end_index)
        arr << {
                  "id" => denotation["id"],
                  "span" => { "begin" => begin_index - range.begin, "end" => end_index - range.begin },
                  "obj" => denotation["obj"]
               }
      elsif (begin_index < range.begin && range.begin < end_index) || (begin_index < range.end && range.end < end_index)
        raise Exceptions::DenotationFragmentedError, "Denotation #{denotation.inspect} fragmented" unless @strict_mode
      elsif (begin_index <= range.begin && range.end < end_index) || (begin_index < range.begin && range.end <= end_index)
        raise Exceptions::DenotationFragmentedError, "Denotation #{denotation.inspect} fragmented" unless @strict_mode
      else
        # If neither begin_index nor end_index is in the range, skip this denotation
        next
      end
    end
  end

  def relations_of(denotations)
    raise ArgumentError, "denotations cannot be nil" if denotations.nil?

    ids = denotations.map { it["id"] }
    @relations.each_with_object([]) do |r, arr|
      subj, obj = r["subj"], r["obj"]
      if ids.include?(subj) && ids.include?(obj)
        arr << r
      elsif ids.include?(subj) || ids.include?(obj)
        raise Exceptions::RelationOutOfRangeError, "Relation #{r.inspect} crosses chunk boundary" unless @strict_mode
      else
        # If neither subject nor object is in the range, skip this relation
        next
      end
    end
  end
end
