class AnnotationMerger
  def initialize(annotations)
    @annotations = annotations
  end

  def merge
    merged_text = ""
    merged_denotations = []
    merged_relations = []
    id_map = {}
    offset = 0
    id_seq = 1

    @annotations.each_with_index do |annotation, idx|
      text = annotation["text"]
      denotations = annotation["denotations"] || []
      relations = annotation["relations"] || []

      # If the end of the text has a period, add a space after it
      offset += 1 if merged_text.last =~ /[.]/
      merged_text += " " if merged_text.last =~ /[.]/
      # Concatenate the existing text and the new text
      merged_text += text
      # Assign a new id to avoid duplication of denotation ids
      denotations.each do |denotation|
        new_id = "T#{id_seq}"
        id_map[denotation["id"]] = new_id
        merged_denotations << {
          "id" => new_id,
          "span" => {
            "begin" => denotation["span"]["begin"] + offset,
            "end" => denotation["span"]["end"] + offset
          },
          "obj" => denotation["obj"]
        }
        id_seq += 1
      end
      relations.each do |relation|
        subj = id_map[relation["subj"]]
        obj = id_map[relation["obj"]]
        # Add only if both ids are mapped
        if subj && obj
          merged_relations << relation.merge("subj" => subj, "obj" => obj)
        end
      end
      offset += text.length
    end

    {
      "text" => merged_text,
      "denotations" => merged_denotations,
      "relations" => merged_relations
    }
  end
end
