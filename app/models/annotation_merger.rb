class AnnotationMerger
  def initialize(annotations)
    @annotations = annotations
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

  # 各チャンクの情報（長さとパディングの有無）を事前計算
  def build_chunks_info
    chunks_info = []

    @annotations.each_with_index do |annotation, index|
      text = annotation["text"] || ""
      has_padding = index > 0 && chunks_info.last&.dig(:cumulative_text)&.end_with?(".")
      padding_length = has_padding ? 1 : 0

      # オフセット計算：前のチャンクの終了位置 + 現在のチャンクのパディング
      offset = if chunks_info.empty?
                 0
      else
                 chunks_info.last[:offset] + chunks_info.last[:length] + padding_length
      end

      cumulative_text = if chunks_info.empty?
                          text
      else
                          previous_text = chunks_info.last[:cumulative_text]
                          padding = has_padding ? " " : ""
                          previous_text + padding + text
      end

      chunks_info << {
        text: text,
        length: text.length,
        has_padding: has_padding,
        padding_length: padding_length,
        cumulative_text: cumulative_text,
        offset: offset
      }
    end

    chunks_info
  end

  # 各チャンクのIDマッピング情報を事前計算
  def build_id_mappings
    id_mappings = []
    id_seq = 1

    @annotations.each_with_index do |annotation, index|
      denotations = annotation["denotations"] || []
      chunk_mapping = {}

      denotations.each do |denotation|
        new_id = "T#{id_seq}"
        chunk_mapping[denotation["id"]] = new_id
        id_seq += 1
      end

      id_mappings << chunk_mapping
    end

    id_mappings
  end

  def merged_text
    @chunks_info.last&.dig(:cumulative_text) || ""
  end

  def merged_denotations
    merged = []

    @annotations.each_with_index do |annotation, index|
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

    merged
  end

  def merged_relations
    merged = []

    @annotations.each_with_index do |annotation, index|
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

    merged
  end
end
