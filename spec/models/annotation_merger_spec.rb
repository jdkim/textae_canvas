require 'rails_helper'

RSpec.describe AnnotationMerger, type: :model do
  describe '#merged' do
    it 'should merge two annotations' do
      ann1 = {
        "text" => "Alice met Bob.",
        "denotations" => [
          { "id" => "T1", "span" => { "begin" => 0, "end" => 5 }, "obj" => "Person" },
          { "id" => "T2", "span" => { "begin" => 10, "end" => 13 }, "obj" => "Person" }
        ],
        "relations" => [
          { "pred" => "met", "subj" => "T1", "obj" => "T2" }
        ]
      }
      ann2 = {
        "text" => "Carol likes Dave.",
        "denotations" => [
          { "id" => "T1", "span" => { "begin" => 0, "end" => 5 }, "obj" => "Person" },
          { "id" => "T2", "span" => { "begin" => 12, "end" => 16 }, "obj" => "Person" }
        ],
        "relations" => [
          { "pred" => "likes", "subj" => "T1", "obj" => "T2" }
        ]
      }

      merged = AnnotationMerger.new([ ann1, ann2 ]).merged

      expect(merged["text"]).to eq "Alice met Bob. Carol likes Dave. "
      expect(merged["denotations"]).to eq [
        { "id" => "T1", "span" => { "begin" => 0, "end" => 5 }, "obj" => "Person" },
        { "id" => "T2", "span" => { "begin" => 10, "end" => 13 }, "obj" => "Person" },
        { "id" => "T3", "span" => { "begin" => 15, "end" => 20 }, "obj" => "Person" },
        { "id" => "T4", "span" => { "begin" => 27, "end" => 31 }, "obj" => "Person" }
      ]
      expect(merged["relations"]).to eq [
        { "pred" => "met", "subj" => "T1", "obj" => "T2" },
        { "pred" => "likes", "subj" => "T3", "obj" => "T4" }
      ]
    end

    it 'should merge with empty relations and denotations' do
      ann1 = { "text" => "Hello.", "denotations" => [], "relations" => [] }
      ann2 = { "text" => "World!", "denotations" => [], "relations" => [] }
      merged = AnnotationMerger.new([ ann1, ann2 ]).merged

      expect(merged["text"]).to eq "Hello. World!"
      expect(merged).not_to have_key("denotations")
      expect(merged).not_to have_key("relations")
    end

    it 'should merge with no relations and denotations' do
      ann1 = { "text" => "Hello." }
      ann2 = { "text" => "World!" }
      merged = AnnotationMerger.new([ ann1, ann2 ]).merged

      expect(merged["text"]).to eq "Hello. World!"
      expect(merged).not_to have_key("denotations")
      expect(merged).not_to have_key("relations")
    end

    it 'should merge multibyte text' do
      ann1 = {
        "text" => "すべての鳥は卵を産む。",
        "denotations" => [ { "id" => "T1", "span" => { "begin" => 4, "end" => 5 }, "obj" => "bird" } ],
        "relations" => []
      }
      ann2 = {
        "text" => "ニワトリは鳥である。",
        "denotations" => [ { "id" => "T1", "span" => { "begin" => 0, "end" => 4 }, "obj" => "chicken" } ],
        "relations" => []
      }
      merged = AnnotationMerger.new([ ann1, ann2 ]).merged

      expect(merged["text"]).to eq "すべての鳥は卵を産む。ニワトリは鳥である。"
      expect(merged["denotations"]).to eq [
        { "id" => "T1", "span" => { "begin" => 4, "end" => 5 }, "obj" => "bird" },
        { "id" => "T2", "span" => { "begin" => 11, "end" => 15 }, "obj" => "chicken" }
      ]
    end
  end
end
