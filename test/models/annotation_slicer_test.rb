require "test_helper"

class AnnotationSlicerTest < ActiveSupport::TestCase
  test "should split in the specified window" do
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

    assert_equal "Alice met Bob.", slice["text"]
    assert_equal [
                   { "id" => "T1", "span" => { "begin" => 0, "end" => 5 }, "obj" => "Person" },
                   { "id" => "T2", "span" => { "begin" => 10, "end" => 13 }, "obj" => "Person" }
                 ], slice["denotations"]
    assert_equal [
                   { "pred" => "met", "subj" => "T1", "obj" => "T2" }
                 ], slice["relations"]

    slice = AnnotationSlicer.new(json_data).annotation_in(15..32)

    assert_equal "Carol likes Dave.", slice["text"]
    assert_equal [
                   { "id" => "T3", "span" => { "begin" => 0, "end" => 5 }, "obj" => "Person" },
                   { "id" => "T4", "span" => { "begin" => 12, "end" => 16 }, "obj" => "Person" }
                 ], slice["denotations"]
    assert_equal [
                   { "pred" => "likes", "subj" => "T3", "obj" => "T4" }
                 ], slice["relations"]
  end

  test "should split into single slice when all annotations fit in window" do
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

    assert_equal json_data["text"], slice["text"]
    assert_equal json_data["denotations"], slice["denotations"]
    assert_equal json_data["relations"], slice["relations"]
  end

  test "should raise denotation fragmented error" do
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

    # Crossing the start of a denotation
    assert_raises(Exceptions::DenotationFragmentedError) do
      AnnotationSlicer.new(json_data).annotation_in(0..20)
    end

    # Trying to cut through the middle of a denotation
    assert_raises(Exceptions::DenotationFragmentedError) do
      AnnotationSlicer.new(json_data).annotation_in(23..26)
    end

    # Crossing the end of a denotation
    assert_raises(Exceptions::DenotationFragmentedError) do
      AnnotationSlicer.new(json_data).annotation_in(27..30)
    end
  end

  test "should not raise denotation fragmented error in non-strict mode" do
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
    slice = AnnotationSlicer.new(json_data, strict_mode: false).annotation_in(0..20)

    assert_equal slice["text"], "Steve Jobs founded A"
    assert_equal slice["denotations"], [
      { "id" => "T1", "span" => { "begin" => 0, "end" => 10 }, "obj" => "Person" }
    ]
    assert_equal slice["relations"], []

    slice = AnnotationSlicer.new(json_data, strict_mode: false).annotation_in(23..26)

    assert_equal slice["text"], "e I"
    assert_equal slice["denotations"], []
    assert_equal slice["relations"], []

    slice = AnnotationSlicer.new(json_data, strict_mode: false).annotation_in(27..30)

    assert_equal slice["text"], "c. "
    assert_equal slice["denotations"], []
    assert_equal slice["relations"], []
  end

  test "should raise relation crosses error when relation crosses chunk boundary" do
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

    assert_raises(Exceptions::RelationOutOfRangeError) do
      AnnotationSlicer.new(json_data).annotation_in(0..21)
    end
  end

  test "should not raise relation crosses error in non-strict mode" do
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

    assert_equal slice["text"], "Elon Musk is a member"
    assert_equal slice["denotations"], [
      { "id" => "T1", "span" => { "begin" => 0, "end" => 9 }, "obj" => "Person" }
    ]
    assert_equal slice["relations"], []
  end

  test "should count multibyte characters as characters not bytes" do
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

    assert_equal "すべての鳥は卵を産む。", slice["text"]
    assert_equal [
                   { "id" => "T1", "span" => { "begin" => 4, "end" => 5 }, "obj" => "bird" },
                   { "id" => "T2", "span" => { "begin" => 6, "end" => 7 }, "obj" => "egg" }
                 ], slice["denotations"]

    slice = AnnotationSlicer.new(json_data).annotation_in(11..21)

    assert_equal "ニワトリは鳥である。", slice["text"]
    assert_equal [
                   { "id" => "T3", "span" => { "begin" => 0, "end" => 4 }, "obj" => "chicken" },
                   { "id" => "T4", "span" => { "begin" => 5, "end" => 6 }, "obj" => "bird" }
                 ], slice["denotations"]
  end

  test "should correctly slice korean sentences as well" do
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

    assert_equal "이순신은 조선의 장군이다.", slice["text"]
    assert_equal [
                   { "id" => "T1", "span" => { "begin" => 0, "end" => 3 }, "obj" => "person" },
                   { "id" => "T2", "span" => { "begin" => 5, "end" => 7 }, "obj" => "country" }
                 ], slice["denotations"]

    slice = AnnotationSlicer.new(json_data).annotation_in(15..30)

    assert_equal "세종대왕은 한글을 창제했다.", slice["text"]
    assert_equal [
                   { "id" => "T3", "span" => { "begin" => 0, "end" => 4 }, "obj" => "person" },
                   { "id" => "T4", "span" => { "begin" => 6, "end" => 8 }, "obj" => "alphabet" }
                 ], slice["denotations"]
  end
end
