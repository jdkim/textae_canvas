class AnnotationMerger
  def initialize(annotations)
    # Preprocessing for text: nil → empty string, add space if ends with a period
    @annotations = annotations.map do |annotation|
      text = annotation["text"] || ""
      text += " " if text.end_with?(".")
      annotation.merge("text" => text)
    end
    @chunks_info = build_chunks_info
    @id_mappings = build_id_mappings
  end

  def merged
    result = { "text" => merged_text }
    result["denotations"] = merged_denotations if merged_denotations.any?
    result["relations"] = merged_relations if merged_relations.any?
    result
  end

  private

  # Pre-calculate information for each chunk (length and offset)
  def build_chunks_info
    @annotations.each_with_object([]).with_index do |(annotation, chunk_info), index|
      text = annotation["text"]
      # Padding check is not necessary because preprocessing is already done
      offset = if chunks_info.empty?
        0
      else
        chunks_info.last[:offset] + chunks_info.last[:length]
      end
      chunks_info << {
        text: text,
        length: text.length,
        offset: offset
      }
    end
  end

  # Pre-calculate ID mapping information for each chunk
  def build_id_mappings
    id_seq = 1

    @annotations.each_with_object([]) do |annotation, id_mappings|
      denotations = annotation["denotations"] || []

      chunk_mapping = denotations.each_with_object({}) do |denotation, mapping|
        new_id = "T#{id_seq}"
        mapping[denotation["id"]] = new_id
        id_seq += 1
      end

      id_mappings << chunk_mapping
    end
  end

  def merged_text
    @annotations.map { |annotation| annotation["text"] }.join
  end

  def merged_denotations
    @annotations.each_with_index.each_with_object([]) do |(annotation, index), merged|
      denotations = annotation["denotations"] || []
      offset = @chunks_info[index][:offset]
      id_mapping = @id_mappings[index]

      denotations.each do |denotation|
        new_id = id_mapping[denotation["id"]]
        merged << {
          "id" => new_id,
          "span" => {
            "begin" => denotation["span"]["begin"] + offset,
            "end" => denotation["span"]["end"] + offset
          },
          "obj" => denotation["obj"]
        }
      end
    end
  end

  def merged_relations
    @annotations.each_with_index.each_with_object([]) do |(annotation, index), merged|
      relations = annotation["relations"] || []
      id_mapping = @id_mappings[index]

      relations.each do |relation|
        subj = id_mapping[relation["subj"]]
        obj = id_mapping[relation["obj"]]

        if subj && obj
          merged << relation.merge("subj" => subj, "obj" => obj)
        end
      end
    end
  end
end
