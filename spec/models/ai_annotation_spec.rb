require 'rails_helper'

RSpec.describe AiAnnotation, type: :model do
  describe '.create!' do
    it 'should create new annotation without deleting old ones' do
      AiAnnotation.create!(content: "aaa", created_at: 2.days.ago)
      AiAnnotation.create!(content: "bbb")

      expect(AiAnnotation.exists?(content: "bbb")).to be_truthy
      expect(AiAnnotation.exists?(content: "aaa")).to be_truthy
    end
  end

  describe 'parent-child branching' do
    it 'creates a child with parent reference' do
      parent = AiAnnotation.create!(content: 'parent', prompt: 'p1')
      child = AiAnnotation.create!(content: 'child', prompt: 'p2', parent: parent)
      expect(child.parent).to eq(parent)
      expect(parent.children).to include(child)
    end

    it 'history_with_branches returns latest first including parent' do
      a1 = AiAnnotation.create!(content: 'a1', prompt: 'p1', created_at: 2.hours.ago)
      a2 = AiAnnotation.create!(content: 'a2', prompt: 'p2', parent: a1, created_at: 1.hour.ago)
      list = AiAnnotation.history_with_branches(limit: 10)
      expect(list.first).to eq(a2)
      expect(list.second).to eq(a1)
      expect(list.first.parent).to eq(a1)
    end

    it 'rejects cycle in parent chain' do
      a1 = AiAnnotation.create!(content: 'a1', prompt: 'p1')
      a2 = AiAnnotation.create!(content: 'a2', prompt: 'p2', parent: a1)
      a1.parent = a2
      expect(a1.valid?).to be_falsey
      expect(a1.errors[:parent]).to be_present
    end
  end

  describe 'ordering' do
    it 'recent orders by created_at desc' do
      a1 = AiAnnotation.create!(content: 'a1', prompt: 'p1')
      sleep 0.01 # Ensure different timestamps
      a2 = AiAnnotation.create!(content: 'a2', prompt: 'p2')
      expect(AiAnnotation.latest.first).to eq(a2)
      expect(AiAnnotation.latest.second).to eq(a1)
    end
  end

  describe 'user scoping' do
    it 'returns only annotations for the given user' do
      u1 = User.create!(email: 'u1@example.com', google_id: 'gid1', id_token: 'tok1')
      u2 = User.create!(email: 'u2@example.com', google_id: 'gid2', id_token: 'tok2')
      a1 = AiAnnotation.create!(content: 'a1', prompt: 'p1', user: u1)
      a2 = AiAnnotation.create!(content: 'a2', prompt: 'p2', user: u2)
      list_u1 = AiAnnotation.history_with_branches(limit: 10, user: u1)
      expect(list_u1).to include(a1)
      expect(list_u1).not_to include(a2)
    end

    it 'returns all when user not specified (backward compatibility)' do
      u1 = User.create!(email: 'u3@example.com', google_id: 'gid3', id_token: 'tok3')
      AiAnnotation.create!(content: 'a3', prompt: 'p3', user: u1)
      expect(AiAnnotation.history_with_branches(limit: 10).count).to be > 0
    end
  end
end
