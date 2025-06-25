require "test_helper"

class AiAnnotationTest < ActiveSupport::TestCase
  test "should delete old annotation when creating new instance" do
    AiAnnotation.create!(content: "aaa", created_at: 2.days.ago)
    AiAnnotation.create!(content: "bbb")

    assert AiAnnotation.exists?(content: "bbb")
    assert_not AiAnnotation.exists?(content: "aaa")
  end

  test "should generate string with inline annotation from JSON" do
    annotation = AiAnnotation.new
    json = {
      "text" => "Elon Musk is a member of the PayPal Mafia.",
      "denotations" => [
        { "span" => { "begin" => 0, "end" => 9 }, "obj" => "Person" },
        { "span" => { "begin" => 29, "end" => 41 }, "obj" => "Organization" }
      ]
    }.to_json
    annotation.set_text_in_json = JSON.parse(json)
    expected = "[Elon Musk][Person] is a member of the [PayPal Mafia][Organization]."
    actual = annotation.text
    assert_equal expected, actual
  end
end
