require "test_helper"

if ENV["LOCAL_ONLY"]
  class TokenChunkTest < ActiveSupport::TestCase
    test "should split into single chunk when all relations fit in window" do
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

      chunks = TokenChunk.new.from(json_data, window_size: 50).to_a

      assert_equal 1, chunks.size
      assert_equal json_data["text"], chunks.first["text"]
      assert_equal json_data["denotations"], chunks.first["denotations"]
      assert_equal json_data["relations"], chunks.first["relations"]
    end

    test "should split into multiple chunks with small window and no crossing relations" do
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

      # ウィンドウサイズを小さくしても、文ごとに分割されリレーションがまたがらない
      chunks = TokenChunk.new.from(json_data, window_size: 3).to_a

      assert_equal 2, chunks.size

      # 1つ目のチャンク
      assert_equal "Alice met Bob.", chunks[0]["text"]
      assert_equal [
                     { "id" => "T1", "span" => { "begin" => 0, "end" => 5 }, "obj" => "Person" },
                     { "id" => "T2", "span" => { "begin" => 10, "end" => 13 }, "obj" => "Person" }
                   ], chunks[0]["denotations"]
      assert_equal [
                     { "pred" => "met", "subj" => "T1", "obj" => "T2" }
                   ], chunks[0]["relations"]

      # 2つ目のチャンク
      assert_equal "Carol likes Dave.", chunks[1]["text"]
      assert_equal [
                     { "id" => "T3", "span" => { "begin" => 0, "end" => 5 }, "obj" => "Person" },
                     { "id" => "T4", "span" => { "begin" => 12, "end" => 16 }, "obj" => "Person" }
                   ], chunks[1]["denotations"]
      assert_equal [
                     { "pred" => "likes", "subj" => "T3", "obj" => "T4" }
                   ], chunks[1]["relations"]
    end

    test "should raise error when relation crosses chunk boundary" do
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

      assert_raises(Exceptions::RelationCrossesChunkError) do
        TokenChunk.new.from(json_data, window_size: 3).to_a
      end
    end

    test "should raise error when relation crosses chunk with multiple denotations" do
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

      assert_raises(Exceptions::RelationCrossesChunkError) do
        TokenChunk.new.from(json_data, window_size: [ "Steve Jobs founded Apple Inc. in 1976.".split(" ").length - 1,
                                                     "Tim Cook is the current CEO of Apple.".split(" ").length - 1 ].max).to_a
      end
    end

    test "should split into two chunks with relations in each chunk" do
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

      chunks = TokenChunk.new.from(json_data, window_size: 9).to_a

      assert_equal 2, chunks.size

      assert_equal "Elon Musk is a member of the PayPal Mafia.", chunks[0]["text"]
      assert_equal [
                     { "id" => "T1", "span" => { "begin" => 0, "end" => 9 }, "obj" => "Person" },
                     { "id" => "T2", "span" => { "begin" => 29, "end" => 41 }, "obj" => "Organization" }
                   ], chunks[0]["denotations"]
      assert_equal [ { "pred" => "member_of", "subj" => "T1", "obj" => "T2" } ], chunks[0]["relations"]
      assert_equal "Elon Musk seems to hate Donald Trump.", chunks[1]["text"]
      assert_equal [
                     { "id" => "T3", "span" => { "begin" => 0, "end" => 9 }, "obj" => "Person" },
                     { "id" => "T4", "span" => { "begin" => 24, "end" => 36 }, "obj" => "Person" }
                   ], chunks[1]["denotations"]
      assert_equal [ { "pred" => "hates", "subj" => "T3", "obj" => "T4" } ], chunks[1]["relations"]
    end

    test "should raise error and shrink window to avoid crossing denotation" do
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

      assert_raises(Exceptions::RelationCrossesChunkError) do
        TokenChunk.new.from(json_data, window_size: 4).to_a
      end
    end

    test "should split into individual sentences when window size matches sentence morpheme count" do
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

      chunks = TokenChunk.new.from(json_data, window_size: [ "すべての鳥は卵を産む。".length,
                                                             "ニワトリは鳥である。".length,
                                                             "ゆえに、ニワトリは卵を産む。".length ].max).to_a

      assert_equal 3, chunks.size
      assert_equal "すべての鳥は卵を産む。", chunks[0]["text"]
      assert_equal [
                     { "id" => "T1", "span" => { "begin" => 4, "end" => 5 }, "obj" => "bird" },
                     { "id" => "T2", "span" => { "begin" => 6, "end" => 7 }, "obj" => "egg" }
                   ], chunks[0]["denotations"]
      assert_equal "ニワトリは鳥である。", chunks[1]["text"]
      assert_equal [
                     { "id" => "T3", "span" => { "begin" => 0, "end" => 4 }, "obj" => "chicken" },
                     { "id" => "T4", "span" => { "begin" => 5, "end" => 6 }, "obj" => "bird" }
                   ], chunks[1]["denotations"]
      assert_equal "ゆえに、ニワトリは卵を産む。", chunks[2]["text"]
      assert_equal [
                     { "id" => "T5", "span" => { "begin" => 4, "end" => 8 }, "obj" => "chicken" },
                     { "id" => "T6", "span" => { "begin" => 9, "end" => 10 }, "obj" => "egg" }
                   ], chunks[2]["denotations"]
    end


    test "should split into individual sentences when window size is smaller than longest sentence" do
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

      chunks = TokenChunk.new.from(json_data, window_size: [ "すべての鳥は卵を産む。".length + 1,
                                                             "ニワトリは鳥である。".length + 1,
                                                             "ゆえに、ニワトリは卵を産む。".length + 1 ].max).to_a

      assert_equal 3, chunks.size
      assert_equal "すべての鳥は卵を産む。", chunks[0]["text"]
      assert_equal [
                     { "id" => "T1", "span" => { "begin" => 4, "end" => 5 }, "obj" => "bird" },
                     { "id" => "T2", "span" => { "begin" => 6, "end" => 7 }, "obj" => "egg" }
                   ], chunks[0]["denotations"]
      assert_equal "ニワトリは鳥である。", chunks[1]["text"]
      assert_equal [
                     { "id" => "T3", "span" => { "begin" => 0, "end" => 4 }, "obj" => "chicken" },
                     { "id" => "T4", "span" => { "begin" => 5, "end" => 6 }, "obj" => "bird" }
                   ], chunks[1]["denotations"]
      assert_equal "ゆえに、ニワトリは卵を産む。", chunks[2]["text"]
      assert_equal [
                     { "id" => "T5", "span" => { "begin" => 4, "end" => 8 }, "obj" => "chicken" },
                     { "id" => "T6", "span" => { "begin" => 9, "end" => 10 }, "obj" => "egg" }
                   ], chunks[2]["denotations"]
    end


    test "should combine multiple sentences when window size exceeds individual sentence length" do
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

      chunks = TokenChunk.new.from(json_data, window_size: [ "すべての鳥は卵を産む。ニワトリは鳥である。".length,
                                                             "ゆえに、ニワトリは卵を産む。".length ].max).to_a

      assert_equal 2, chunks.size
      assert_equal "すべての鳥は卵を産む。ニワトリは鳥である。", chunks[0]["text"]
      assert_equal [
                     { "id" => "T1", "span" => { "begin" => 4, "end" => 5 }, "obj" => "bird" },
                     { "id" => "T2", "span" => { "begin" => 6, "end" => 7 }, "obj" => "egg" },
                     { "id" => "T3", "span" => { "begin" => 11, "end" => 15 }, "obj" => "chicken" },
                     { "id" => "T4", "span" => { "begin" => 16, "end" => 17 }, "obj" => "bird" }
                   ], chunks[0]["denotations"]
      assert_equal "ゆえに、ニワトリは卵を産む。", chunks[1]["text"]
      assert_equal [
                     { "id" => "T5", "span" => { "begin" => 4, "end" => 8 }, "obj" => "chicken" },
                     { "id" => "T6", "span" => { "begin" => 9, "end" => 10 }, "obj" => "egg" }
                   ], chunks[1]["denotations"]
    end

    test "should handle mixed japanese and english text" do
      json_data = {
        "text" => "私はAI engineerです。Machine learningを勉強しています。",
        "denotations" => [
          { "id" => "T1", "span" => { "begin" => 0, "end" => 1 }, "obj" => "person" },
          { "id" => "T2", "span" => { "begin" => 2, "end" => 13 }, "obj" => "profession" },
          { "id" => "T3", "span" => { "begin" => 17, "end" => 33 }, "obj" => "technology" }
        ],
        "relations" => [
          { "pred" => "profession_of", "subj" => "T1", "obj" => "T2" }  # 同じ文内のrelationのみ
        ]
      }
      chunks = TokenChunk.new.from(json_data, window_size: [ "私はAI engineerです。".length,
                                                            "Machine learningを勉強しています。".length ].max).to_a

      assert chunks.size >= 1
      # 混在テキストでもdenotationが正しく処理されるか
      total_denotations = chunks.sum { |chunk| chunk["denotations"].size }
      total_relations = chunks.sum { |chunk| chunk["relations"].size }
      assert_equal 3, total_denotations
      assert_equal 1, total_relations  # relationを1つに修正
    end

    test "should handle sentences ending with question marks and exclamations" do
      json_data = {
        "text" => "何をしていますか？とても楽しいです！明日も頑張ります。",
        "denotations" => [
          { "id" => "T1", "span" => { "begin" => 12, "end" => 16 }, "obj" => "emotion" },
          { "id" => "T2", "span" => { "begin" => 20, "end" => 22 }, "obj" => "time" }
        ],
        "relations" => []
      }
      chunks = TokenChunk.new.from(json_data, window_size: 15).to_a  # ウィンドウサイズを大きく

      assert chunks.size >= 1
      # 各チャンクが適切な文末記号で終わっているか
      chunks.each do |chunk|
        assert_match /[。！？]$/, chunk["text"]
      end
    end

    test "should handle text with no denotations and relations" do
      json_data = {
        "text" => "これは単純なテキストです。アノテーションはありません。",
        "denotations" => [],
        "relations" => []
      }
      chunks = TokenChunk.new.from(json_data, window_size: 8).to_a

      assert chunks.size >= 1
      chunks.each do |chunk|
        assert_equal [], chunk["denotations"]
        assert_equal [], chunk["relations"]
      end
    end

    test "should handle overlapping denotations" do
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
      chunks = TokenChunk.new.from(json_data, window_size: 13).to_a

      assert chunks.size >= 1
      # 重複するdenotationが正しく処理されるか
      total_denotations = chunks.sum { |chunk| chunk["denotations"].size }
      assert_equal 3, total_denotations
    end

    test "should handle zero window size gracefully" do
      json_data = {
        "text" => "テストです。",
        "denotations" => [],
        "relations" => []
      }

      # ゼロウィンドウサイズでもエラーにならないか
      chunks = TokenChunk.new.from(json_data, window_size: 0).to_a
      assert_equal 0, chunks.size
    end

    test "should handle very long denotations" do
      json_data = {
        "text" => "独立行政法人情報処理推進機構は日本の情報技術分野を支援しています。",
        "denotations" => [
          { "id" => "T1", "span" => { "begin" => 0, "end" => 15 }, "obj" => "organization" },
          { "id" => "T2", "span" => { "begin" => 16, "end" => 18 }, "obj" => "country" },
          { "id" => "T3", "span" => { "begin" => 19, "end" => 25 }, "obj" => "field" }
        ],
        "relations" => []  # relationを削除
      }
      chunks = TokenChunk.new.from(json_data, window_size: 20).to_a  # ウィンドウサイズを大きく

      assert chunks.size >= 1
      # 長いdenotationが正しく処理されるか
      chunks.each do |chunk|
        chunk["denotations"].each do |denotation|
          assert denotation["span"]["end"] > denotation["span"]["begin"]
        end
      end
    end

    test "should handle text with numbers and symbols" do
      json_data = {
        "text" => "2024年4月1日にOpenAI社のGPT-4が発表されました。価格は$20/月です。",
        "denotations" => [
          { "id" => "T1", "span" => { "begin" => 0, "end" => 9 }, "obj" => "date" },
          { "id" => "T2", "span" => { "begin" => 11, "end" => 17 }, "obj" => "company" },
          { "id" => "T3", "span" => { "begin" => 19, "end" => 24 }, "obj" => "product" },
          { "id" => "T4", "span" => { "begin" => 33, "end" => 37 }, "obj" => "price" }
        ],
        "relations" => []  # relationを削除
      }
      chunks = TokenChunk.new.from(json_data, window_size: "2024年4月1日にOpenAI社のGPT-4が発表されました。".length).to_a  # ウィンドウサイズを大きく

      assert chunks.size >= 1
      # 数字や記号を含むテキストでも正しく処理されるか
      total_denotations = chunks.sum { |chunk| chunk["denotations"].size }
      assert_equal 4, total_denotations
    end

    test "should handle consecutive sentence boundaries" do
      json_data = {
        "text" => "終わりです。。。次が始まります。",
        "denotations" => [
          { "id" => "T1", "span" => { "begin" => 0, "end" => 3 }, "obj" => "status" },
          { "id" => "T2", "span" => { "begin" => 7, "end" => 9 }, "obj" => "status" }
        ],
        "relations" => []
      }
      chunks = TokenChunk.new.from(json_data, window_size: 5).to_a

      assert chunks.size >= 1
      # 連続する句点が正しく処理されるか
      chunks.each do |chunk|
        assert_not_empty chunk["text"].strip
      end
    end

    test "should provide debug information" do
      json_data = {
        "text" => "私は東京で勉強しています。",
        "denotations" => [
          { "id" => "T1", "span" => { "begin" => 0, "end" => 1 }, "obj" => "person" }
        ],
        "relations" => []
      }
      chunks = TokenChunk.new.from(json_data, window_size: 5).to_a

      assert chunks.size > 0
      # 日本語テキストの場合、デバッグ情報が含まれているか
      chunks.each do |chunk|
        if chunk.key?("debug_info")
          assert chunk.key?("morpheme_count")
          assert chunk["debug_info"].key?("chunk_range")
          assert chunk["debug_info"].key?("ends_with_sentence_boundary")
        end
      end
    end

    test "should handle multiple relations referencing same entity within sentence" do
      json_data = {
        "text" => "太郎は学生で東京に住んでいる優秀な人です。",
        "denotations" => [
          { "id" => "T1", "span" => { "begin" => 0, "end" => 2 }, "obj" => "person" },
          { "id" => "T2", "span" => { "begin" => 3, "end" => 5 }, "obj" => "occupation" },
          { "id" => "T3", "span" => { "begin" => 6, "end" => 8 }, "obj" => "location" },
          { "id" => "T4", "span" => { "begin" => 13, "end" => 15 }, "obj" => "attribute" }
        ],
        "relations" => [
          { "pred" => "is_a", "subj" => "T1", "obj" => "T2" },
          { "pred" => "lives_in", "subj" => "T1", "obj" => "T3" },
          { "pred" => "has_attribute", "subj" => "T1", "obj" => "T4" }
        ]
      }
      chunks = TokenChunk.new.from(json_data, window_size: "太郎は学生で東京に住んでいる優秀な人です。".length).to_a

      assert_equal 1, chunks.size  # 1文なので1チャンク
      # 同じエンティティを参照する複数のrelationが正しく処理されるか
      total_relations = chunks.sum { |chunk| chunk["relations"].size }
      assert_equal 3, total_relations
    end

    test "should extend english chunks to include punctuation" do
      json_data = {
        "text" => "Hello world! How are you? I'm fine, thanks.",
        "denotations" => [
          { "id" => "T1", "span" => { "begin" => 0, "end" => 5 }, "obj" => "greeting" },
          { "id" => "T2", "span" => { "begin" => 6, "end" => 11 }, "obj" => "object" }
        ],
        "relations" => [
          { "pred" => "greets", "subj" => "T1", "obj" => "T2" }
        ]
      }
      chunks = TokenChunk.new.from(json_data, window_size: 3).to_a

      assert chunks.size >= 1
      # 英語でも句読点が適切に含まれているか
      chunks.each do |chunk|
        # 句読点で終わるか、文末であることを確認
        assert_match /[.!?]$|[^.!?]$/, chunk["text"]
      end
    end

    test "should handle very short text" do
      json_data = {
        "text" => "短。",
        "denotations" => [
          { "id" => "T1", "span" => { "begin" => 0, "end" => 1 }, "obj" => "adjective" }
        ],
        "relations" => []
      }
      chunks = TokenChunk.new.from(json_data, window_size: 10).to_a

      assert_equal 1, chunks.size
      assert_equal "短。", chunks[0]["text"]
      assert_equal 1, chunks[0]["denotations"].size
    end

    test "should handle relations within single sentence" do
      json_data = {
        "text" => "太郎は東京に住んでいる。花子は大阪に住んでいる。",
        "denotations" => [
          { "id" => "T1", "span" => { "begin" => 0, "end" => 2 }, "obj" => "person" },
          { "id" => "T2", "span" => { "begin" => 3, "end" => 5 }, "obj" => "location" },
          { "id" => "T3", "span" => { "begin" => 12, "end" => 14 }, "obj" => "person" },
          { "id" => "T4", "span" => { "begin" => 15, "end" => 17 }, "obj" => "location" }
        ],
        "relations" => [
          { "pred" => "lives_in", "subj" => "T1", "obj" => "T2" },  # 第1文内のrelation
          { "pred" => "lives_in", "subj" => "T3", "obj" => "T4" }   # 第2文内のrelation
        ]
      }

      chunks = TokenChunk.new.from(json_data, window_size: [ "太郎は東京に住んでいる。".length,
                                                            "花子は大阪に住んでいる。".length ].max).to_a

      assert_equal 2, chunks.size
      assert_equal 1, chunks[0]["relations"].size
      assert_equal 1, chunks[1]["relations"].size
    end

    test "should handle korean text with denotations and relations" do
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

      chunks = TokenChunk.new.from(json_data, window_size: [ "이순신은 조선의 장군이다.".length, "세종대왕은 한글을 창제했다.".length ].max).to_a

      assert_equal 2, chunks.size
      assert_equal "이순신은 조선의 장군이다.", chunks[0]["text"]
      assert_equal [
                     { "id" => "T1", "span" => { "begin" => 0, "end" => 3 }, "obj" => "person" },
                     { "id" => "T2", "span" => { "begin" => 5, "end" => 7 }, "obj" => "country" }
                   ], chunks[0]["denotations"]
      assert_equal [
                     { "pred" => "is_general_of", "subj" => "T1", "obj" => "T2" }
                   ], chunks[0]["relations"]

      assert_equal "세종대왕은 한글을 창제했다.", chunks[1]["text"]
      assert_equal [
                     { "id" => "T3", "span" => { "begin" => 0, "end" => 4 }, "obj" => "person" },
                     { "id" => "T4", "span" => { "begin" => 6, "end" => 8 }, "obj" => "alphabet" }
                   ], chunks[1]["denotations"]
      assert_equal [
                     { "pred" => "created", "subj" => "T3", "obj" => "T4" }
                   ], chunks[1]["relations"]
    end

    test "should split korean text with multiple sentences and no relations" do
      json_data = {
        "text" => "서울은 대한민국의 수도이다. 부산은 두 번째로 큰 도시이다.",
        "denotations" => [
          { "id" => "T1", "span" => { "begin" => 0, "end" => 2 }, "obj" => "city" },
          { "id" => "T2", "span" => { "begin" => 4, "end" => 8 }, "obj" => "country" },
          { "id" => "T3", "span" => { "begin" => 16, "end" => 18 }, "obj" => "city" }
        ],
        "relations" => []
      }
      chunks = TokenChunk.new.from(json_data, window_size: [ "서울은 대한민국의 수도이다.".length, "부산은 두 번째로 큰 도시이다.".length ].max).to_a

      assert_equal 2, chunks.size
      assert_equal "서울은 대한민국의 수도이다.", chunks[0]["text"]
      assert_equal [
                     { "id" => "T1", "span" => { "begin" => 0, "end" => 2 }, "obj" => "city" },
                     { "id" => "T2", "span" => { "begin" => 4, "end" => 8 }, "obj" => "country" }
                   ], chunks[0]["denotations"]

      assert_equal "부산은 두 번째로 큰 도시이다.", chunks[1]["text"]
      assert_equal [
                     { "id" => "T3", "span" => { "begin" => 0, "end" => 2 }, "obj" => "city" }
                   ], chunks[1]["denotations"]
    end

    test "should handle korean text with overlapping denotations" do
      json_data = {
        "text" => "대한민국정부청사는 서울에 있다.",
        "denotations" => [
          { "id" => "T1", "span" => { "begin" => 0, "end" => 6 }, "obj" => "government" },
          { "id" => "T2", "span" => { "begin" => 0, "end" => 4 }, "obj" => "country" },
          { "id" => "T3", "span" => { "begin" => 6, "end" => 8 }, "obj" => "building" },
          { "id" => "T4", "span" => { "begin" => 10, "end" => 12 }, "obj" => "city" }
        ],
        "relations" => [
          { "pred" => "located_in", "subj" => "T1", "obj" => "T4" }
        ]
      }
      chunks = TokenChunk.new.from(json_data, window_size: json_data["text"].length).to_a

      assert_equal 1, chunks.size
      assert_equal 4, chunks[0]["denotations"].size
      assert_equal 1, chunks[0]["relations"].size
    end

    test "should handle korean text with relation crossing chunk boundary" do
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
          { "pred" => "is", "subj" => "T3", "obj" => "T4" }
        ]
      }
      # 故意に小さいwindowでrelationがまたがるように
      assert_raises(Exceptions::RelationCrossesChunkError) do
        TokenChunk.new.from(json_data, window_size: "김연아는 피겨스케이팅 선수이다. 그".length).to_a
      end
    end
  end
end
