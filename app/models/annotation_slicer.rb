class AnnotationSlicer
  def initialize(annotation)
    @text = annotation["text"]
    @denotations = annotation["denotations"] || []
    @relations = annotation["relations"] || []
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
    @denotations.each_with_object([]) do |denotation, arr|
      begin_index = denotation["span"]["begin"]
      end_index = denotation["span"]["end"]
      if range.cover?(begin_index..end_index)
        arr << {
                  "id" => denotation["id"],
                  "span" => { "begin" => begin_index - range.begin, "end" => end_index - range.begin },
                  "obj" => denotation["obj"]
               }
      elsif (!range.begin.nil? && begin_index < range.begin && range.begin < end_index) || (!range.end.nil? && begin_index < range.end && range.end < end_index)
        raise Exceptions::DenotationFragmentedError, "Denotation #{denotation.inspect} fragmented"
      elsif !range.begin.nil? && !range.end.nil? && ((begin_index <= range.begin && range.end < end_index) || (begin_index < range.begin && range.end <= end_index))
        raise Exceptions::DenotationFragmentedError, "Denotation #{denotation.inspect} fragmented"
      else
        nil
      end
    end.compact
  end

  def relations_of(denotations)
    ids = denotations.map { it["id"] }
    @relations.each_with_object([]) do |r, arr|
      subj, obj = r["subj"], r["obj"]
      if ids.include?(subj) && ids.include?(obj)
        arr << r
      elsif ids.include?(subj) || ids.include?(obj)
        raise Exceptions::RelationOutOfRangeError, "Relation #{r.inspect} crosses chunk boundary"
      else
        # If neither subject nor object is in the range, skip this relation
        next
      end
    end
  end
end
