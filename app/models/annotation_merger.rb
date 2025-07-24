class AnnotationMerger
  def initialize(annotations)
    @annotations = annotations
  end

  def merge
    id_seq = 1
    id_map = {}
    offset = 0
    merged_text = ""
    merged_denotations = []
    merged_relations = []

    @annotations.each do |annotation|
      text = annotation["text"]
      denotations = annotation["denotations"] || []
      relations = annotation["relations"] || []

      if merged_text.end_with?(".")
        merged_text += " "
        offset += 1
      end
      merged_text += text

      # Merge denotations (also returns id_map and id_seq)
      denotations_result = merge_denotations denotations, offset, id_seq, id_map
      merged_denotations.concat denotations_result[:denotations]
      id_map = denotations_result[:id_map]
      id_seq = denotations_result[:id_seq]

      # Merge relations
      merged_relations.concat merge_relations(relations, id_map)
      offset += text.length
    end

    {
      "text" => merged_text,
      "denotations" => merged_denotations,
      "relations" => merged_relations
    }
  end

  private

  def merge_denotations(denotations, offset, id_seq, id_map)
    merged = []
    denotations.each do |denotation|
      new_id = "T#{id_seq}"
      id_map = id_map.merge({ denotation["id"] => new_id })
      merged << {
        "id" => new_id,
        "span" => {
          "begin" => denotation["span"]["begin"] + offset,
          "end" => denotation["span"]["end"] + offset
        },
        "obj" => denotation["obj"]
      }
      id_seq += 1
    end

    {
      denotations: merged,
      id_map: id_map,
      id_seq: id_seq
    }
  end

  def merge_relations(relations, id_map)
    merged = []
    relations.each do |relation|
      subj = id_map[relation["subj"]]
      obj = id_map[relation["obj"]]
      if subj && obj
        merged << relation.merge("subj" => subj, "obj" => obj)
      end
    end
    merged
  end
end
