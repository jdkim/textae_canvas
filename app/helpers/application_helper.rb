module ApplicationHelper
  def short_uuid(uuid)
    uuid.to_s.split('-').first
  end

  def render_history(ai_annotations, active_uuid: nil)
    content_tag(:div, class: 'history-stack', data: { controller: 'history' }) do
      result = []
      ai_annotations.each_with_index do |ann, idx|
        number_label = "p#{ann.sequence_number}" # 保存された通し番号
        parent_uuid = ann.parent&.uuid
        classes = ['history-card']
        classes << 'is-active' if active_uuid.present? && ann.uuid == active_uuid
        inner = content_tag(:div, truncate(ann.prompt.to_s, length: 50), class: 'history-card-prompt') +
                content_tag(:div, short_uuid(ann.uuid), class: 'history-card-uuid')
        link = link_to(inner.html_safe, edit_ai_annotation_path(ann.uuid), class: 'history-card-link')
        card = content_tag(:div, link, class: classes.join(' '),
                           data: { uuid: ann.uuid, parent_uuid: parent_uuid })
        result << card

        # 現在のカードの親が直前のカード(降順なのでsequence_numberが1つ大きい)なら直線矢印を挿入
        if idx > 0
          next_ann = ai_annotations[idx + 1]
          if next_ann && ann.parent&.uuid == next_ann.uuid
            result << content_tag(:div, '↑', class: 'history-straight-arrow')
          end
        end
      end
      result.join.html_safe + content_tag(:svg, '', class: 'history-arrows', data: { history_target: 'svg' })
    end
  end
end
