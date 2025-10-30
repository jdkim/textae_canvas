require 'rails_helper'

RSpec.describe AiAnnotation, type: :model do
  describe '.create!' do
    it 'should delete old annotation when creating new instance' do
      AiAnnotation.create!(content: "aaa", created_at: 2.days.ago)
      AiAnnotation.create!(content: "bbb")

      expect(AiAnnotation.exists?(content: "bbb")).to be_truthy
      expect(AiAnnotation.exists?(content: "aaa")).to be_falsy
    end
  end
end
