module AiAnnotationHelper

  def render_history(ai_annotations, active_uuid: nil)
    content_tag(:div, class: "history-stack", data: { controller: "history" }) do
      result = []
      ai_annotations.each_with_index do |ann, idx|
        parent_uuid = ann.parent&.uuid
        classes = [ "history-card" ]
        classes << "is-active" if active_uuid.present? && ann.uuid == active_uuid
        inner = content_tag(:div, truncate(ann.prompt.to_s, length: 50), class: "history-card-prompt") +
                content_tag(:div, short_uuid(ann.uuid), class: "history-card-uuid")
        link = link_to(inner.html_safe, edit_ai_annotation_path(ann.uuid), class: "history-card-link")
        card = content_tag(:div, link, class: classes.join(" "),
                           data: { uuid: ann.uuid, parent_uuid: parent_uuid })
        result << card

        # Insert a straight arrow if the next (older) element is the parent of the current element
        if idx < ai_annotations.length - 1
          next_ann = ai_annotations[idx + 1]
          if next_ann && ann.parent&.uuid == next_ann.uuid
            result << content_tag(:div, "↑", class: "history-straight-arrow")
          end
        end
      end
      result.join.html_safe + content_tag(:svg, "", class: "history-arrows", data: { history_target: "svg" })
    end
  end

  private

  def short_uuid(uuid)
    uuid.to_s.split("-").first
  end
end

