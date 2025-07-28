require "test_helper"

class AnnotationMergerTest < ActiveSupport::TestCase
  test "should merge two annotations" do
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

    assert_equal "Alice met Bob. Carol likes Dave. ", merged["text"]
    assert_equal [
      { "id" => "T1", "span" => { "begin" => 0, "end" => 5 }, "obj" => "Person" },
      { "id" => "T2", "span" => { "begin" => 10, "end" => 13 }, "obj" => "Person" },
      { "id" => "T3", "span" => { "begin" => 15, "end" => 20 }, "obj" => "Person" },
      { "id" => "T4", "span" => { "begin" => 27, "end" => 31 }, "obj" => "Person" }
    ], merged["denotations"]
    assert_equal [
      { "pred" => "met", "subj" => "T1", "obj" => "T2" },
      { "pred" => "likes", "subj" => "T3", "obj" => "T4" }
    ], merged["relations"]
  end

  test "should merge with empty relations and denotations" do
    ann1 = { "text" => "Hello.", "denotations" => [], "relations" => [] }
    ann2 = { "text" => "World!", "denotations" => [], "relations" => [] }
    merged = AnnotationMerger.new([ ann1, ann2 ]).merged
    assert_equal "Hello. World!", merged["text"]
    assert_not merged.key?("denotations")
    assert_not merged.key?("relations")
  end

  test "should merge with no relations and denotations" do
    ann1 = { "text" => "Hello." }
    ann2 = { "text" => "World!" }
    merged = AnnotationMerger.new([ ann1, ann2 ]).merged
    assert_equal "Hello. World!", merged["text"]
    assert_not merged.key?("denotations")
    assert_not merged.key?("relations")
  end

  test "should merge multibyte text" do
    ann1 = { "text" => "すべての鳥は卵を産む。", "denotations" => [ { "id" => "T1", "span" => { "begin" => 4, "end" => 5 }, "obj" => "bird" } ], "relations" => [] }
    ann2 = { "text" => "ニワトリは鳥である。", "denotations" => [ { "id" => "T1", "span" => { "begin" => 0, "end" => 4 }, "obj" => "chicken" } ], "relations" => [] }
    merged = AnnotationMerger.new([ ann1, ann2 ]).merged
    assert_equal "すべての鳥は卵を産む。ニワトリは鳥である。", merged["text"]
    assert_equal [
      { "id" => "T1", "span" => { "begin" => 4, "end" => 5 }, "obj" => "bird" },
      { "id" => "T2", "span" => { "begin" => 11, "end" => 15 }, "obj" => "chicken" }
    ], merged["denotations"]
  end
end
