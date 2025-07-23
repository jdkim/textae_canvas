require "test_helper"

class AnnotationSlicerTest < ActiveSupport::TestCase
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

  test "should split into multiple slices with small window and no crossing relations" do
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

    slice = AnnotationSlicer.new(json_data).annotation_in(15..)

    assert_equal "Carol likes Dave.", slice["text"]
    assert_equal [
                   { "id" => "T3", "span" => { "begin" => 0, "end" => 5 }, "obj" => "Person" },
                   { "id" => "T4", "span" => { "begin" => 12, "end" => 16 }, "obj" => "Person" }
                 ], slice["denotations"]
    assert_equal [
                   { "pred" => "likes", "subj" => "T3", "obj" => "T4" }
                 ], slice["relations"]
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

    assert_raises(Exceptions::DenotationFragmentedError) do
      AnnotationSlicer.new(json_data).annotation_in(0..5)
    end
    assert_raises(Exceptions::DenotationFragmentedError) do
      AnnotationSlicer.new(json_data).annotation_in(6..24)
    end
  end

  test "should raise denotation fragmented error for extremely long denotation" do
    json_data = {
      "text" => "a" * 100,
      "denotations" => [
        { "id" => "T1", "span" => { "begin" => 0, "end" => 99 }, "obj" => "LongEntity" }
      ],
      "relations" => []
    }

    assert_raises(Exceptions::DenotationFragmentedError) do
      AnnotationSlicer.new(json_data).annotation_in(10..20)
    end
  end

  test "should split into individual english sentences" do
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

    slice = AnnotationSlicer.new(json_data).annotation_in(0..42)

    assert_equal "Elon Musk is a member of the PayPal Mafia.", slice["text"]
    assert_equal [
                   { "id" => "T1", "span" => { "begin" => 0, "end" => 9 }, "obj" => "Person" },
                   { "id" => "T2", "span" => { "begin" => 29, "end" => 41 }, "obj" => "Organization" }
                 ], slice["denotations"]
    assert_equal [ { "pred" => "member_of", "subj" => "T1", "obj" => "T2" } ], slice["relations"]

    slice = AnnotationSlicer.new(json_data).annotation_in(43..)

    assert_equal "Elon Musk seems to hate Donald Trump.", slice["text"]
    assert_equal [
                   { "id" => "T3", "span" => { "begin" => 0, "end" => 9 }, "obj" => "Person" },
                   { "id" => "T4", "span" => { "begin" => 24, "end" => 36 }, "obj" => "Person" }
                 ], slice["denotations"]
    assert_equal [ { "pred" => "hates", "subj" => "T3", "obj" => "T4" } ], slice["relations"]
  end

  test "should split into individual japanese sentences" do
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

    slice = AnnotationSlicer.new(json_data).annotation_in(0..11)

    assert_equal "すべての鳥は卵を産む。", slice["text"]
    assert_equal [
                   { "id" => "T1", "span" => { "begin" => 4, "end" => 5 }, "obj" => "bird" },
                   { "id" => "T2", "span" => { "begin" => 6, "end" => 7 }, "obj" => "egg" }
                 ], slice["denotations"]
    assert_equal [
                   { "pred" => "lay", "subj" => "T1", "obj" => "T2" }
                 ], slice["relations"]

    slice = AnnotationSlicer.new(json_data).annotation_in(11..21)

    assert_equal "ニワトリは鳥である。", slice["text"]
    assert_equal [
                   { "id" => "T3", "span" => { "begin" => 0, "end" => 4 }, "obj" => "chicken" },
                   { "id" => "T4", "span" => { "begin" => 5, "end" => 6 }, "obj" => "bird" }
                 ], slice["denotations"]
    assert_equal [
                   { "pred" => "lay", "subj" => "T3", "obj" => "T4" }
                 ], slice["relations"]

    slice = AnnotationSlicer.new(json_data).annotation_in(21..)

    assert_equal "ゆえに、ニワトリは卵を産む。", slice["text"]
    assert_equal [
                   { "id" => "T5", "span" => { "begin" => 4, "end" => 8 }, "obj" => "chicken" },
                   { "id" => "T6", "span" => { "begin" => 9, "end" => 10 }, "obj" => "egg" }
                 ], slice["denotations"]
    assert_equal [
                   { "pred" => "lay", "subj" => "T5", "obj" => "T6" }
                 ], slice["relations"]
  end

  test "should split into individual korean sentences" do
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

    slice = AnnotationSlicer.new(json_data).annotation_in(0..14)

    assert_equal "이순신은 조선의 장군이다.", slice["text"]
    assert_equal [
                   { "id" => "T1", "span" => { "begin" => 0, "end" => 3 }, "obj" => "person" },
                   { "id" => "T2", "span" => { "begin" => 5, "end" => 7 }, "obj" => "country" }
                 ], slice["denotations"]
    assert_equal [
                   { "pred" => "is_general_of", "subj" => "T1", "obj" => "T2" }
                 ], slice["relations"]

    slice = AnnotationSlicer.new(json_data).annotation_in(15..)

    assert_equal "세종대왕은 한글을 창제했다.", slice["text"]
    assert_equal [
                   { "id" => "T3", "span" => { "begin" => 0, "end" => 4 }, "obj" => "person" },
                   { "id" => "T4", "span" => { "begin" => 6, "end" => 8 }, "obj" => "alphabet" }
                 ], slice["denotations"]
    assert_equal [
                   { "pred" => "created", "subj" => "T3", "obj" => "T4" }
                 ], slice["relations"]
  end
end
