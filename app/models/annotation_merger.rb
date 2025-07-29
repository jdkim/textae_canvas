class AnnotationMerger
  def initialize(annotations)
    # If annotation["text"] is nil, set it to an empty string.
    # If the text ends with a period, add a space to clarify sentence boundaries when merging annotations.
    # This prevents loss of readability or meaning.
    # Setting nil to an empty string also avoids errors in subsequent processing.
    # Ensure consistent denotations and relations format for reliable merging.
    @annotations = annotations.map do |annotation|
      text = annotation["text"] || ""
      text += " " if text.end_with?(".")
      denotations = annotation["denotations"] || []
      relations = annotation["relations"] || []
      annotation.merge("text" => text, "denotations" => denotations, "relations" => relations)
    end
    @chunks_info = chunks_info
    @id_mappings = id_mappings
  end

  def merged
    result = { "text" => merged_text }
    result["denotations"] = merged_denotations if merged_denotations.any?
    result["relations"] = merged_relations if merged_relations.any?
    result
  end

  private

  # Pre-calculate information for each chunk (length and offset)
  def chunks_info
    @annotations.each_with_object([]).with_index do |(annotation, chunks_info), index|
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
  def id_mappings
    id_seq = 1

    @annotations.each_with_object([]) do |annotation, id_mappings|
      denotations = annotation["denotations"]

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
      denotations = annotation["denotations"]
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
      relations = annotation["relations"]
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
