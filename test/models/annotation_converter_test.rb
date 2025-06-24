require "test_helper"

class AnnotationConverterTest < ActiveSupport::TestCase

  test "should generate string with inline annotation from JSON" do
    json = {
      "text" => "Elon Musk is a member of the PayPal Mafia.",
      "denotations" => [
        { "span" => { "begin" => 0, "end" => 9 }, "obj" => "Person" },
        { "span" => { "begin" => 29, "end" => 41 }, "obj" => "Organization" }
      ]
    }.to_json
    expected = "[Elon Musk][Person] is a member of the [PayPal Mafia][Organization]."
    assert_equal expected, AnnotationConverter.new.to_inline(json)
  end
end
