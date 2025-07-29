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

    # Check referential integrity of relations
    @annotations.each_with_index do |annotation, idx|
      relations = annotation["relations"]
      denotations = annotation["denotations"]
      relations.each do |relation|
        unless referable_to?(relation, denotations)
          raise ArgumentError, "Relation #{relation.inspect} in chunk #{idx + 1} refers to missing denotation."
        end
      end
    end
  end

  def merged
    result = { "text" => merged_text }
    result["denotations"] = merged_denotations if merged_denotations.any?
    result["relations"] = merged_relations if merged_relations.any?
    result
  end

  private

  def referable_to?(relation, denotations)
    denotation_ids = denotations.map { it["id"] }
    denotation_ids.include?(relation["subj"]) && denotation_ids.include?(relation["obj"])
  end

  # Pre-calculate information for each chunk (length and offset)
  def chunks_info
    @chunks_info ||= @annotations.each_with_object([]).with_index do |(annotation, chunks_info), index|
      text = annotation["text"]
      offset = if chunks_info.last
        chunks_info.last[:offset] + chunks_info.last[:length]
      else
        0
      end

      chunks_info << {
        text:,
        length: text.length,
        offset:
      }
    end
  end

  # Pre-calculate ID mapping information for each chunk
  def id_mappings
    id_seq = 1

    @id_mappings ||= @annotations.map do |annotation|
                       denotations = annotation["denotations"]

                       denotations.filter{ it["id"].present? }
                                  .each_with_object({}) do |denotation, chunk_mapping|
                         original_id = denotation["id"]
                         new_id = "T#{id_seq}"
                         chunk_mapping[original_id] = new_id
                         id_seq += 1
                       end
                     end
  end

  def merged_text
    @annotations.map { |annotation| annotation["text"] }.join
  end

  def merged_denotations
    @annotations.each_with_object([]).with_index do |(annotation, merged), index|
      denotations = annotation["denotations"]
      offset = chunks_info[index][:offset]
      id_mapping = id_mappings[index]

      denotations.each do |denotation|
        merged << merge_denotation(denotation, offset, id_mapping)
      end
    end
  end

  def merge_denotation(original_denotation, offset, id_mapping)
    merged = {
      "span" => {
        "begin" => original_denotation["span"]["begin"] + offset,
        "end" => original_denotation["span"]["end"] + offset
      },
      "obj" => original_denotation["obj"]
    }

    if original_denotation["id"]
      merged["id"] = id_mapping[original_denotation["id"]]
    end

    merged
  end

  # Merge relations and remap IDs
  def merged_relations
    @annotations.each_with_index.each_with_object([]) do |(annotation, index), merged|
      relations = annotation["relations"]
      id_mapping = id_mappings[index]

      relations.each do |relation|
        subj = id_mapping[relation["subj"]]
        obj = id_mapping[relation["obj"]]
        merged << relation.merge("subj" => subj, "obj" => obj)
      end
    end
  end
end
