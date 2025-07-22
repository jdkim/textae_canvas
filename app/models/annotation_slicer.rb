class AnnotationSlicer
  def initialize(json_data)
    @text = json_data["text"]
    @denotations = json_data["denotations"] || []
    @relations = json_data["relations"] || []
  end

  def annotation_in(range)
    {
      "text" => @text[range.begin...range.end],
      "denotations" => denotations_in(range),
      "relations" => relations_of(denotations_in range)
    }
  end

  def denotations_in(range)
    @denotations.map do |denotation|
      begin_index = denotation["span"]["begin"]
      end_index = denotation["span"]["end"]
      if range.cover?(begin_index..end_index)
        {
          "id" => denotation["id"],
          "span" => { "begin" => begin_index - range.begin, "end" => end_index - range.begin },
          "obj" => denotation["obj"]
        }
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
        raise Exceptions::RelationCrossesChunkError, "Relation #{r.inspect} crosses chunk boundary"
      else
        # If neither subject nor object is in the range, skip this relation
        next
      end
    end
  end
end
