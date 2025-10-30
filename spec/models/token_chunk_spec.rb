require 'rails_helper'

RSpec.describe TokenChunk, type: :model do
  before do
    skip unless ENV["LOCAL_ONLY"]
  end

  describe '.from' do
    it 'should split into single chunk when all relations fit in window' do
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

      chunks = TokenChunk.from(json_data, window_size: 50)

      expect(chunks.size).to eq 1
      expect(chunks.first["text"]).to eq json_data["text"]
      expect(chunks.first["denotations"]).to eq json_data["denotations"]
      expect(chunks.first["relations"]).to eq json_data["relations"]
    end

    it 'should split into one chunk for long window size' do
      json_data = {
        "text" => "Humpty Dumpty sat on a wall. Humpty Dumpty had a great fall. All the king's horses and all the king's men Couldn't put Humpty together again.",
        "denotations" => [],
        "relations" => []
      }

      chunks = TokenChunk.from(json_data, window_size: 50)

      expect(chunks.size).to eq 1
      expect(chunks.first["text"]).to eq json_data["text"]
      expect(chunks.first["denotations"]).to eq json_data["denotations"]
      expect(chunks.first["relations"]).to eq json_data["relations"]
    end

    it 'should split into three chunks for short window size' do
      json_data = {
        "text" => "Humpty Dumpty sat on a wall. Humpty Dumpty had a great fall. All the king's horses and all the king's men Couldn't put Humpty together again.",
        "denotations" => [],
        "relations" => []
      }

      chunks = TokenChunk.from(json_data, window_size: 5)

      expect(chunks.size).to eq 3
      expect(chunks[0]["text"]).to eq "Humpty Dumpty sat on a wall."
      expect(chunks[1]["text"]).to eq "Humpty Dumpty had a great fall."
      expect(chunks[2]["text"]).to eq "All the king's horses and all the king's men Couldn't put Humpty together again."
      expect(chunks.first["denotations"]).to eq json_data["denotations"]
      expect(chunks.first["relations"]).to eq json_data["relations"]
    end

    it 'should split into multiple chunks with small window and no crossing relations' do
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

      chunks = TokenChunk.from(json_data, window_size: 3)

      expect(chunks.size).to eq 2

      # 1つ目のチャンク
      expect(chunks[0]["text"]).to eq "Alice met Bob."
      expect(chunks[0]["denotations"]).to eq [
        { "id" => "T1", "span" => { "begin" => 0, "end" => 5 }, "obj" => "Person" },
        { "id" => "T2", "span" => { "begin" => 10, "end" => 13 }, "obj" => "Person" }
      ]
      expect(chunks[0]["relations"]).to eq [
        { "pred" => "met", "subj" => "T1", "obj" => "T2" }
      ]

      # 2つ目のチャンク
      expect(chunks[1]["text"]).to eq "Carol likes Dave."
      expect(chunks[1]["denotations"]).to eq [
        { "id" => "T3", "span" => { "begin" => 0, "end" => 5 }, "obj" => "Person" },
        { "id" => "T4", "span" => { "begin" => 12, "end" => 16 }, "obj" => "Person" }
      ]
      expect(chunks[1]["relations"]).to eq [
        { "pred" => "likes", "subj" => "T3", "obj" => "T4" }
      ]
    end

    it 'should raise error when relation crosses chunk boundary' do
      json_data = {
        "text" => "Elon Musk is a member of the PayPal Mafia. He is clever.",
        "denotations" => [
          { "id" => "T1", "span" => { "begin" => 0, "end" => 9 }, "obj" => "Person" },
          { "id" => "T2", "span" => { "begin" => 29, "end" => 41 }, "obj" => "Organization" },
          { "id" => "T3", "span" => { "begin" => 43, "end" => 45 }, "obj" => "Person" }
        ],
        "relations" => [
          { "pred" => "member_of", "subj" => "T1", "obj" => "T2" },
          { "pred" => "is", "subj" => "T1", "obj" => "T3" }
        ]
      }

      expect {
        TokenChunk.from(json_data, window_size: 3)
      }.to raise_error(Exceptions::RelationOutOfRangeError)
    end

    it 'should split into two chunks with relations in each chunk' do
      json_data = {
        "text" => "Elon Musk is a member of the PayPal Mafia. Elon Musk seems to hate Donald Trump.",
        "denotations" => [
          { "id" => "T1", "span" => { "begin" => 0, "end" => 9 }, "obj" => "Person" },
          { "id" => "T2", "span" => { "begin" => 29, "end" => 41 }, "obj" => "Organization" },
          { "id" => "T3", "span" => { "begin" => 43, "end" => 52 }, "obj" => "Person" },
          { "id" => "T4", "span" => { "begin" => 67, "end" => 79 }, "obj" => "Person" }
        ],
        "relations" => [
          { "pred" => "member_of", "subj" => "T1", "obj" => "T2" },
          { "pred" => "hates", "subj" => "T3", "obj" => "T4" }
        ]
      }

      chunks = TokenChunk.from(json_data, window_size: 9)

      expect(chunks.size).to eq 2

      expect(chunks[0]["text"]).to eq "Elon Musk is a member of the PayPal Mafia."
      expect(chunks[0]["denotations"]).to eq [
        { "id" => "T1", "span" => { "begin" => 0, "end" => 9 }, "obj" => "Person" },
        { "id" => "T2", "span" => { "begin" => 29, "end" => 41 }, "obj" => "Organization" }
      ]
      expect(chunks[0]["relations"]).to eq [ { "pred" => "member_of", "subj" => "T1", "obj" => "T2" } ]

      expect(chunks[1]["text"]).to eq "Elon Musk seems to hate Donald Trump."
      expect(chunks[1]["denotations"]).to eq [
        { "id" => "T3", "span" => { "begin" => 0, "end" => 9 }, "obj" => "Person" },
        { "id" => "T4", "span" => { "begin" => 24, "end" => 36 }, "obj" => "Person" }
      ]
      expect(chunks[1]["relations"]).to eq [ { "pred" => "hates", "subj" => "T3", "obj" => "T4" } ]
    end

    context 'with complex text and relations' do
      it 'should split into individual sentences when window size matches sentence morpheme count' do
        json_data = {
          "text" => "すべての鳥は卵を産む。ニワトリは鳥である。ゆえに、ニワトリは卵を産む。",
          "denotations" => [
            { "id" => "T1", "span" => { "begin" => 4, "end" => 5 }, "obj" => "bird" },
            { "id" => "T2", "span" => { "begin" => 6, "end" => 7 }, "obj" => "egg" },
            { "id" => "T3", "span" => { "begin" => 11, "end" => 15 }, "obj" => "chicken" },
            { "id" => "T4", "span" => { "begin" => 16, "end" => 17 }, "obj" => "bird" },
            { "id" => "T5", "span" => { "begin" => 25, "end" => 29 }, "obj" => "chicken" },
            { "id" => "T6", "span" => { "begin" => 30, "end" => 31 }, "obj" => "egg" }
          ],
          "relations" => [
            { "pred" => "lay", "subj" => "T1", "obj" => "T2" },
            { "pred" => "lay", "subj" => "T3", "obj" => "T4" },
            { "pred" => "lay", "subj" => "T5", "obj" => "T6" }
          ]
        }

        window_size = [ "すべての鳥は卵を産む。".length, "ニワトリは鳥である。".length, "ゆえに、ニワトリは卵を産む。".length ].max
        chunks = TokenChunk.from(json_data, window_size: window_size)

        expect(chunks.size).to eq 3
        expect(chunks[0]["text"]).to eq "すべての鳥は卵を産む。"
        expect(chunks[0]["denotations"]).to eq [
          { "id" => "T1", "span" => { "begin" => 4, "end" => 5 }, "obj" => "bird" },
          { "id" => "T2", "span" => { "begin" => 6, "end" => 7 }, "obj" => "egg" }
        ]
        expect(chunks[1]["text"]).to eq "ニワトリは鳥である。"
        expect(chunks[1]["denotations"]).to eq [
          { "id" => "T3", "span" => { "begin" => 0, "end" => 4 }, "obj" => "chicken" },
          { "id" => "T4", "span" => { "begin" => 5, "end" => 6 }, "obj" => "bird" }
        ]
        expect(chunks[2]["text"]).to eq "ゆえに、ニワトリは卵を産む。"
        expect(chunks[2]["denotations"]).to eq [
          { "id" => "T5", "span" => { "begin" => 4, "end" => 8 }, "obj" => "chicken" },
          { "id" => "T6", "span" => { "begin" => 9, "end" => 10 }, "obj" => "egg" }
        ]
      end

      it 'should handle korean text with denotations and relations' do
        json_data = {
          "text" => "이순신은 조선의 장군이다. 세종대왕은 한글을 창제했다.",
          "denotations" => [
            { "id" => "T1", "span" => { "begin" => 0, "end" => 3 }, "obj" => "person" },
            { "id" => "T2", "span" => { "begin" => 5, "end" => 7 }, "obj" => "country" },
            { "id" => "T3", "span" => { "begin" => 15, "end" => 19 }, "obj" => "person" },
            { "id" => "T4", "span" => { "begin" => 21, "end" => 23 }, "obj" => "alphabet" }
          ],
          "relations" => [
            { "pred" => "is_general_of", "subj" => "T1", "obj" => "T2" },
            { "pred" => "created", "subj" => "T3", "obj" => "T4" }
          ]
        }

        chunks = TokenChunk.from(json_data, window_size: 15)

        expect(chunks.size).to eq 2
        expect(chunks[0]["text"]).to eq "이순신은 조선의 장군이다."
        expect(chunks[0]["denotations"]).to eq [
          { "id" => "T1", "span" => { "begin" => 0, "end" => 3 }, "obj" => "person" },
          { "id" => "T2", "span" => { "begin" => 5, "end" => 7 }, "obj" => "country" }
        ]
        expect(chunks[0]["relations"]).to eq [
          { "pred" => "is_general_of", "subj" => "T1", "obj" => "T2" }
        ]

        expect(chunks[1]["text"]).to eq "세종대왕은 한글을 창제했다."
        expect(chunks[1]["denotations"]).to eq [
          { "id" => "T3", "span" => { "begin" => 0, "end" => 4 }, "obj" => "person" },
          { "id" => "T4", "span" => { "begin" => 6, "end" => 8 }, "obj" => "alphabet" }
        ]
        expect(chunks[1]["relations"]).to eq [
          { "pred" => "created", "subj" => "T3", "obj" => "T4" }
        ]
      end
    end

    context 'error conditions' do
      it 'should raise error when window size is zero' do
        json_data = {
          "text" => "テストです。",
          "denotations" => [],
          "relations" => []
        }

        expect {
          TokenChunk.from(json_data, window_size: 0)
        }.to raise_error(ArgumentError)
      end

      it 'should raise error and shrink window to avoid crossing denotation' do
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
            { "pred" => "ceo_of", "subj" => "T3", "obj" => "T4" },
            { "pred" => "friend", "subj" => "T1", "obj" => "T3" }
          ]
        }

        expect {
          TokenChunk.from(json_data, window_size: 3)
        }.to raise_error(Exceptions::RelationOutOfRangeError)
      end

      it 'should handle korean text with relation crossing chunk boundary' do
        json_data = {
          "text" => "김연아는 피겨스케이팅 선수이다. 그녀는 올림픽 금메달리스트이다.",
          "denotations" => [
            { "id" => "T1", "span" => { "begin" => 0, "end" => 3 }, "obj" => "person" },
            { "id" => "T2", "span" => { "begin" => 5, "end" => 11 }, "obj" => "sport" },
            { "id" => "T3", "span" => { "begin" => 18, "end" => 20 }, "obj" => "person" },
            { "id" => "T4", "span" => { "begin" => 22, "end" => 32 }, "obj" => "title" }
          ],
          "relations" => [
            { "pred" => "is", "subj" => "T1", "obj" => "T2" },
            { "pred" => "equals", "subj" => "T1", "obj" => "T3" },
            { "pred" => "is", "subj" => "T3", "obj" => "T4" },
            { "pred" => "noun", "subj" => "T1", "obj" => "T4" }
          ]
        }

        expect {
          TokenChunk.from(json_data, window_size: "김연아는 피겨스케이팅 선수이다. 그".length)
        }.to raise_error(Exceptions::RelationOutOfRangeError)
      end
    end

    context 'edge cases' do
      it 'should handle very short text' do
        json_data = {
          "text" => "短。",
          "denotations" => [
            { "id" => "T1", "span" => { "begin" => 0, "end" => 1 }, "obj" => "adjective" }
          ],
          "relations" => []
        }
        chunks = TokenChunk.from(json_data, window_size: 10)

        expect(chunks.size).to eq 1
        expect(chunks[0]["text"]).to eq "短。"
        expect(chunks[0]["denotations"].size).to eq 1
      end

      it 'should handle text with no denotations and relations' do
        json_data = {
          "text" => "これは単純なテキストです。アノテーションはありません。",
          "denotations" => [],
          "relations" => []
        }
        chunks = TokenChunk.from(json_data, window_size: 8)

        expect(chunks.size).to be >= 1
        chunks.each do |chunk|
          expect(chunk["denotations"]).to eq []
          expect(chunk["relations"]).to eq []
        end
      end

      it 'should handle overlapping denotations' do
        json_data = {
          "text" => "東京大学医学部は有名です。",
          "denotations" => [
            { "id" => "T1", "span" => { "begin" => 0, "end" => 4 }, "obj" => "university" },
            { "id" => "T2", "span" => { "begin" => 0, "end" => 7 }, "obj" => "medical_school" },
            { "id" => "T3", "span" => { "begin" => 4, "end" => 7 }, "obj" => "department" }
          ],
          "relations" => [
            { "pred" => "part_of", "subj" => "T3", "obj" => "T1" }
          ]
        }
        chunks = TokenChunk.from(json_data, window_size: 13)

        expect(chunks.size).to be >= 1
        total_denotations = chunks.sum { |chunk| chunk["denotations"].size }
        expect(total_denotations).to eq 3
      end
    end
  end
end
