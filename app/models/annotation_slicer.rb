class AnnotationSlicer
  def initialize(original_text, original_denotations, original_relations)
    @text = original_text
    @denotations = original_denotations || []
    @relations = original_relations || []
  end

  def annotation_in(range)
    denotations = denotations_in range
    relations = relations_in_chunk denotations
    chunk_text = @text[range.begin...range.end]
    {
      "text" => chunk_text,
      "denotations" => denotations,
      "relations" => relations
    }
  end

  def denotations_in(range)
    @denotations.map do |d|
      d_start = d["span"]["begin"]
      d_end = d["span"]["end"]
      if d_start >= range.begin && d_end <= range.end
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

  def relations_in_chunk(chunk_denotations)
    chunk_ids = chunk_denotations.map { |it| it["id"] }
    @relations.each_with_object([]) do |r, arr|
      subj, obj = r["subj"], r["obj"]
      if chunk_ids.include?(subj) && chunk_ids.include?(obj)
        arr << r
      elsif chunk_ids.include?(subj) || chunk_ids.include?(obj)
        raise Exceptions::RelationCrossesChunkError, "Relation #{r.inspect} crosses chunk boundary"
      else
        # If neither subject nor object is in the chunk, skip this relation
        next
      end
    end
  end
end
