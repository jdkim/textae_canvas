require 'rails_helper'

RSpec.describe AnnotationSlicer, type: :model do
  describe '#annotation_in' do
    it 'should split in the specified window' do
      json_data = {
        "text" => "Alice met Bob. Carol likes Dave.",
        "denotations" => [
          { "id" => "T1", "span" => { "begin" => 0, "end" => 5 }, "obj" => "Person" },
          { "id" => "T2", "span" => { "begin" => 10, "end" => 13 }, "obj" => "Person" },
          { "id" => "T3", "span" => { "begin" => 15, "end" => 20 }, "obj" => "Person" },
          { "id" => "T4", "span" => { "begin" => 27, "end" => 31 }, "obj" => "Person" }
        ],
        "relations" => [
          { "pred" => "met", "subj" => "T1", "obj" => "T2" },
          { "pred" => "likes", "subj" => "T3", "obj" => "T4" }
        ]
      }

      # Even with a small window size, it should be divided by sentence and relations should not cross
      slice = AnnotationSlicer.new(json_data).annotation_in(0..14)

      expect(slice["text"]).to eq "Alice met Bob."
      expect(slice["denotations"]).to eq [
        { "id" => "T1", "span" => { "begin" => 0, "end" => 5 }, "obj" => "Person" },
        { "id" => "T2", "span" => { "begin" => 10, "end" => 13 }, "obj" => "Person" }
      ]
      expect(slice["relations"]).to eq [
        { "pred" => "met", "subj" => "T1", "obj" => "T2" }
      ]

      slice = AnnotationSlicer.new(json_data).annotation_in(15..32)

      expect(slice["text"]).to eq "Carol likes Dave."
      expect(slice["denotations"]).to eq [
        { "id" => "T3", "span" => { "begin" => 0, "end" => 5 }, "obj" => "Person" },
        { "id" => "T4", "span" => { "begin" => 12, "end" => 16 }, "obj" => "Person" }
      ]
      expect(slice["relations"]).to eq [
        { "pred" => "likes", "subj" => "T3", "obj" => "T4" }
      ]
    end

    it 'should split into single slice when all annotations fit in window' do
      json_data = {
        "text" => "Steve Jobs founded Apple Inc. in 1976. Tim Cook is the current CEO of Apple.",
        "denotations" => [
          { "id" => "T1", "span" => { "begin" => 0, "end" => 10 }, "obj" => "Person" },
          { "id" => "T2", "span" => { "begin" => 19, "end" => 28 }, "obj" => "Organization" },
          { "id" => "T3", "span" => { "begin" => 39, "end" => 47 }, "obj" => "Person" },
          { "id" => "T4", "span" => { "begin" => 70, "end" => 75 }, "obj" => "Organization" }
        ],
        "relations" => [
          { "pred" => "founder_of", "subj" => "T1", "obj" => "T2" },
          { "pred" => "ceo_of", "subj" => "T3", "obj" => "T4" }
        ]
      }

      slice = AnnotationSlicer.new(json_data).annotation_in(0..78)

      expect(slice["text"]).to eq json_data["text"]
      expect(slice["denotations"]).to eq json_data["denotations"]
      expect(slice["relations"]).to eq json_data["relations"]
    end

    it 'should raise denotation fragmented error' do
      json_data = {
        "text" => "Steve Jobs founded Apple Inc. in 1976. Tim Cook is the current CEO of Apple.",
        "denotations" => [
          { "id" => "T1", "span" => { "begin" => 0, "end" => 10 }, "obj" => "Person" },
          { "id" => "T2", "span" => { "begin" => 19, "end" => 28 }, "obj" => "Organization" }
        ],
        "relations" => [
          { "pred" => "founder_of", "subj" => "T1", "obj" => "T2" }
        ]
      }

      # Crossing the start of a denotation
      expect {
        AnnotationSlicer.new(json_data).annotation_in(0..20)
      }.to raise_error(Exceptions::DenotationFragmentedError)

      # Trying to cut through the middle of a denotation
      expect {
        AnnotationSlicer.new(json_data).annotation_in(23..26)
      }.to raise_error(Exceptions::DenotationFragmentedError)

      # Crossing the end of a denotation
      expect {
        AnnotationSlicer.new(json_data).annotation_in(27..30)
      }.to raise_error(Exceptions::DenotationFragmentedError)
    end

    context 'in non-strict mode' do
      it 'should disappear some denotations and not raise denotation fragmented error' do
        json_data = {
          "text" => "Steve Jobs founded Apple Inc. in 1976. Tim Cook is the current CEO of Apple.",
          "denotations" => [
            { "id" => "T1", "span" => { "begin" => 0, "end" => 10 }, "obj" => "Person" },
            { "id" => "T2", "span" => { "begin" => 19, "end" => 28 }, "obj" => "Organization" }
          ],
          "relations" => [
            { "pred" => "founder_of", "subj" => "T1", "obj" => "T2" }
          ]
        }
        slice = AnnotationSlicer.new(json_data, strict_mode: false).annotation_in(0..20)

        expect(slice["text"]).to eq "Steve Jobs founded A"
        expect(slice["denotations"]).to eq [
          { "id" => "T1", "span" => { "begin" => 0, "end" => 10 }, "obj" => "Person" }
        ]
        expect(slice["relations"]).to eq []

        slice = AnnotationSlicer.new(json_data, strict_mode: false).annotation_in(23..26)

        expect(slice["text"]).to eq "e I"
        expect(slice["denotations"]).to eq []
        expect(slice["relations"]).to eq []

        slice = AnnotationSlicer.new(json_data, strict_mode: false).annotation_in(27..30)

        expect(slice["text"]).to eq "c. "
        expect(slice["denotations"]).to eq []
        expect(slice["relations"]).to eq []
      end

      it 'should disappear some relations and not raise relation crosses error' do
        json_data = {
          "text" => "Elon Musk is a member of the PayPal Mafia.",
          "denotations" => [
            { "id" => "T1", "span" => { "begin" => 0, "end" => 9 }, "obj" => "Person" },
            { "id" => "T2", "span" => { "begin" => 29, "end" => 41 }, "obj" => "Organization" }
          ],
          "relations" => [
            { "pred" => "member_of", "subj" => "T1", "obj" => "T2" }
          ]
        }
        slice = AnnotationSlicer.new(json_data, strict_mode: false).annotation_in(0..21)

        expect(slice["text"]).to eq "Elon Musk is a member"
        expect(slice["denotations"]).to eq [
          { "id" => "T1", "span" => { "begin" => 0, "end" => 9 }, "obj" => "Person" }
        ]
        expect(slice["relations"]).to eq []
      end
    end

    it 'should raise relation crosses error when relation crosses chunk boundary' do
      json_data = {
        "text" => "Elon Musk is a member of the PayPal Mafia.",
        "denotations" => [
          { "id" => "T1", "span" => { "begin" => 0, "end" => 9 }, "obj" => "Person" },
          { "id" => "T2", "span" => { "begin" => 29, "end" => 41 }, "obj" => "Organization" }
        ],
        "relations" => [
          { "pred" => "member_of", "subj" => "T1", "obj" => "T2" }
        ]
      }

      expect {
        AnnotationSlicer.new(json_data).annotation_in(0..21)
      }.to raise_error(Exceptions::RelationOutOfRangeError)
    end

    it 'should count multibyte characters as characters not bytes' do
      json_data = {
        "text" => "すべての鳥は卵を産む。ニワトリは鳥である。ゆえに、ニワトリは卵を産む。",
        "denotations" => [
          { "id" => "T1", "span" => { "begin" => 4, "end" => 5 }, "obj" => "bird" },
          { "id" => "T2", "span" => { "begin" => 6, "end" => 7 }, "obj" => "egg" },
          { "id" => "T3", "span" => { "begin" => 11, "end" => 15 }, "obj" => "chicken" },
          { "id" => "T4", "span" => { "begin" => 16, "end" => 17 }, "obj" => "bird" },
          { "id" => "T5", "span" => { "begin" => 25, "end" => 29 }, "obj" => "chicken" },
          { "id" => "T6", "span" => { "begin" => 30, "end" => 31 }, "obj" => "egg" }
        ]
      }

      slice = AnnotationSlicer.new(json_data).annotation_in(0..11)

      expect(slice["text"]).to eq "すべての鳥は卵を産む。"
      expect(slice["denotations"]).to eq [
        { "id" => "T1", "span" => { "begin" => 4, "end" => 5 }, "obj" => "bird" },
        { "id" => "T2", "span" => { "begin" => 6, "end" => 7 }, "obj" => "egg" }
      ]

      slice = AnnotationSlicer.new(json_data).annotation_in(11..21)

      expect(slice["text"]).to eq "ニワトリは鳥である。"
      expect(slice["denotations"]).to eq [
        { "id" => "T3", "span" => { "begin" => 0, "end" => 4 }, "obj" => "chicken" },
        { "id" => "T4", "span" => { "begin" => 5, "end" => 6 }, "obj" => "bird" }
      ]
    end

    it 'should correctly slice korean sentences as well' do
      json_data = {
        "text" => "이순신은 조선의 장군이다. 세종대왕은 한글을 창제했다.",
        "denotations" => [
          { "id" => "T1", "span" => { "begin" => 0, "end" => 3 }, "obj" => "person" },
          { "id" => "T2", "span" => { "begin" => 5, "end" => 7 }, "obj" => "country" },
          { "id" => "T3", "span" => { "begin" => 15, "end" => 19 }, "obj" => "person" },
          { "id" => "T4", "span" => { "begin" => 21, "end" => 23 }, "obj" => "alphabet" }
        ]
      }

      slice = AnnotationSlicer.new(json_data).annotation_in(0..14)

      expect(slice["text"]).to eq "이순신은 조선의 장군이다."
      expect(slice["denotations"]).to eq [
        { "id" => "T1", "span" => { "begin" => 0, "end" => 3 }, "obj" => "person" },
        { "id" => "T2", "span" => { "begin" => 5, "end" => 7 }, "obj" => "country" }
      ]

      slice = AnnotationSlicer.new(json_data).annotation_in(15..30)

      expect(slice["text"]).to eq "세종대왕은 한글을 창제했다."
      expect(slice["denotations"]).to eq [
        { "id" => "T3", "span" => { "begin" => 0, "end" => 4 }, "obj" => "person" },
        { "id" => "T4", "span" => { "begin" => 6, "end" => 8 }, "obj" => "alphabet" }
      ]
    end
  end
end
