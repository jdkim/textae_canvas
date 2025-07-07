require "test_helper"

class WordChunkTest < ActiveSupport::TestCase
  test "should extract single chunk for short text" do
    text = "This is a short text with less than fifty words."
    chunks = WordChunk.from text, window_size: 50

    assert_equal 1, chunks.count
    assert_equal text, chunks.first
  end

  test "should not split when word count is less than window size" do
    # Create text with more than 50 words
    text = "word1 word2 word3 word4 word5"

    chunks = WordChunk.from text, window_size: 5

    assert_equal 1, chunks.count
    assert_equal 5, chunks.first.split.size
  end

  test "should split into two chunks when word count is just over window size" do
    # Create text with more than 50 words
    text = "word1 word2 word3 word4 word5 word6"

    chunks = WordChunk.from text, window_size: 5

    assert_equal 2, chunks.count
    assert_equal 5, chunks.first.split.size
    assert_equal 1, chunks.drop(1).first.split.size
  end

  test "should preserve newlines in chunks" do
    text = "First line\nSecond line\nThird line"
    chunks = WordChunk.from text, window_size: 1

    assert_equal 8,         chunks.count
    assert_equal "First",   chunks.first
    assert_equal "line",    chunks.drop(1).first
    assert_equal "\n",      chunks.drop(2).first
    assert_equal "Second",  chunks.drop(3).first
    assert_equal "line",    chunks.drop(4).first
    assert_equal "\n",      chunks.drop(5).first
    assert_equal "Third",   chunks.drop(6).first
    assert_equal "line",    chunks.drop(7).first
  end

  test "should handle empty text" do
    text = ""
    chunks = WordChunk.from text, window_size: 50

    assert_equal 0, chunks.count
  end

  test "should handle text with multiple consecutive newlines" do
    text = "First paragraph\n\n\nSecond paragraph"
    chunks = WordChunk.from text, window_size: 50

    assert_equal 1, chunks.count
    assert_equal "First paragraph", chunks.first[0..14]
    assert_equal "\n", chunks.first[15]
    assert_equal "\n", chunks.first[16]
    assert_equal "\n", chunks.first[17]
    assert_equal "Second paragraph", chunks.first[19..34]
  end

  test "should split into two equal chunks when word count is exactly double window size" do
    # Create text with exactly 100 words (should create 2 chunks of 50 each)
    words = Array.new(100) { |i| "word#{i}" }
    text = words.join(" ")

    chunks = WordChunk.from text, window_size: 50

    assert_equal 2, chunks.count
    assert_equal 50, chunks.first.split.size
    assert_equal 50, chunks.drop(1).first.split.size
  end

  test "should split into three chunks when word count is just over double window size" do
    # Create text with exactly 100 words (should create 2 chunks of 50 each)
    words = Array.new(101) { |i| "word#{i}" }
    text = words.join(" ")

    chunks = WordChunk.from text, window_size: 50

    assert_equal 3, chunks.count
    assert_equal 50, chunks.first.split.size
    assert_equal 50, chunks.drop(1).first.split.size
    assert_equal 1, chunks.drop(2).first.split.size
  end

  test "should return enumerator when called without to_a" do
    text = "This is a test text"
    result = WordChunk.from text, window_size: 50

    assert_instance_of Enumerator, result
  end

  test "should handle text with special characters" do
    text = "Text with special characters: @#$%^&*()!? and numbers 123456"
    chunks = WordChunk.from text, window_size: 50

    assert_equal 1, chunks.count
    assert_equal "@#$%^&*()!?", chunks.first[30..40]
    assert_equal "123456", chunks.first[54..60]
  end

  test "should normalize line endings" do
    text_with_crlf = "Line one\r\nLine two\r\nLine three"
    chunks = WordChunk.from text_with_crlf, window_size: 50

    assert_equal 1, chunks.count
    assert_not_equal "\r\n", chunks.first[8..9]
    assert_equal "\n", chunks.first[8]
    assert_not_equal "\r\n", chunks.first[18..19]
    assert_equal "\n", chunks.first[18]
  end
end
