class ChunkExtractor
  def initialize(original_text, original_denotations, original_relations)
    @original_text = original_text
    @original_denotations = original_denotations || []
    @original_relations = original_relations || []
  end

  def build_chunk_data(chunk_start, chunk_end)
    denotations = denotations_in_chunk chunk_start, chunk_end
    relations = relations_in_chunk denotations
    chunk_text = @original_text[chunk_start...chunk_end]
    {
      "text" => chunk_text,
      "denotations" => denotations,
      "relations" => relations
    }
  end

  def denotations_in_chunk(chunk_start, chunk_end)
    @original_denotations.map do |d|
      d_start = d["span"]["begin"]
      d_end = d["span"]["end"]
      if d_start >= chunk_start && d_end <= chunk_end
        {
          "id" => d["id"],
          "span" => { "begin" => d_start - chunk_start, "end" => d_end - chunk_start },
          "obj" => d["obj"]
        }
      else
        nil
      end
    end.compact
  end

  def relations_in_chunk(chunk_denotations)
    chunk_ids = chunk_denotations.map { |it| it["id"] }
    @original_relations.each_with_object([]) do |r, arr|
      subj, obj = r["subj"], r["obj"]
      if chunk_ids.include?(subj) && chunk_ids.include?(obj)
        arr << r
      elsif chunk_ids.include?(subj) || chunk_ids.include?(obj)
        raise Exceptions::RelationCrossesChunkError, "Relation #{r.inspect} crosses chunk boundary"
      else
        next
      end
    end
  end
end
