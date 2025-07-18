class AnnotationSlicer
  def initialize(original_text, original_denotations, original_relations)
    @text = original_text
    @denotations = original_denotations || []
    @relations = original_relations || []
  end

  def annotation_in(range)
    {
      "text" => denotations_in range,
      "denotations" => relations_of denotations,
      "relations" => @text[range.begin...range.end]
    }
  end

  def denotations_in(range)
    @denotations.map do |d|
      d_start = d["span"]["begin"]
      d_end = d["span"]["end"]
      if range.begin <= d_start && d_end <= range.end
        {
          "id" => d["id"],
          "span" => { "begin" => d_start - range.begin, "end" => d_end - range.begin },
          "obj" => d["obj"]
        }
      else
        nil
      end
    end.compact
  end

  def relations_of(denotations)
    ids = denotations.map { |it| it["id"] }
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
