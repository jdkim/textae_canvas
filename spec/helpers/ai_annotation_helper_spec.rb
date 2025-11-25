require 'rails_helper'

RSpec.describe AiAnnotationHelper, type: :helper do
  describe '#render_history' do
    let(:parent_annotation) { AiAnnotation.create!(content: 'parent content', prompt: 'Parent prompt') }
    let(:child_annotation) { AiAnnotation.create!(content: 'child content', prompt: 'Child prompt', parent: parent_annotation) }

    it 'renders arrow between parent and child annotations' do
      ai_annotations = [ child_annotation, parent_annotation ] # 最新順

      result = helper.render_history(ai_annotations)

      expect(result).to include('history-straight-arrow')
      expect(result).to include('↑')
    end

    it 'does not render arrow when there is no parent-child relationship' do
      annotation1 = AiAnnotation.create!(content: 'content1', prompt: 'Prompt 1')
      annotation2 = AiAnnotation.create!(content: 'content2', prompt: 'Prompt 2')

      ai_annotations = [ annotation1, annotation2 ]

      result = helper.render_history(ai_annotations)

      expect(result).not_to include('history-straight-arrow')
    end

    it 'renders multiple arrows for chain of annotations' do
      grandparent = AiAnnotation.create!(content: 'grandparent content', prompt: 'Grandparent')
      parent = AiAnnotation.create!(content: 'parent content', prompt: 'Parent', parent: grandparent)
      child = AiAnnotation.create!(content: 'child content', prompt: 'Child', parent: parent)

      ai_annotations = [ child, parent, grandparent ]

      result = helper.render_history(ai_annotations)

      # Verify that two arrows are displayed
      expect(result.scan(/history-straight-arrow/).length).to eq(2)
    end
  end
end
