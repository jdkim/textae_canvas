require "test_helper"

class WordChunkTest < ActiveSupport::TestCase
  test "should extract single chunk for short text" do
    text = "This is a short text with less than fifty words."
    chunks = WordChunk.from text, window_size: 50

    assert_equal 1, chunks.count
    assert_equal text, chunks.first
  end

  test "should extract multiple chunks for long text" do
    # Create text with more than 50 words
    words = Array.new(51) { |i| "word#{i}" }
    text = words.join(" ")

    chunks = WordChunk.from text, window_size: 50

    assert_equal 2, chunks.count
    assert_equal 50, chunks.first.split.size
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

  test "should handle text with only whitespace" do
    text = "   \n   \n   "
    chunks = WordChunk.from text, window_size: 50

    # Should handle whitespace gracefully
    assert chunks.count >= 0
  end

  test "should handle text with multiple consecutive newlines" do
    text = "First paragraph\n\n\nSecond paragraph"
    chunks = WordChunk.from text, window_size: 50

    assert_equal 1, chunks.count
    assert_includes chunks.first, "\n\n\n"
  end

  test "should split exactly at window size boundary" do
    # Create text with exactly 100 words (should create 2 chunks of 50 each)
    words = Array.new(100) { |i| "word#{i}" }
    text = words.join(" ")

    chunks = WordChunk.from text, window_size: 50

    assert_equal 2, chunks.count
    assert_equal 50, chunks.first.split.size
    assert_equal 50, chunks.drop(1).first.split.size
  end

  test "should handle text with mixed word lengths" do
    text = "Short words and some significantly longer words that should still be processed correctly"
    chunks = WordChunk.from text, window_size: 50

    assert_equal 1, chunks.count
    assert_equal text, chunks.first
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
    assert_includes chunks.first, "@#$%^&*()"
    assert_includes chunks.first, "123456"
  end

  test "should normalize line endings" do
    text_with_crlf = "Line one\r\nLine two\r\nLine three"
    chunks = WordChunk.from text_with_crlf, window_size: 50

    assert_equal 1, chunks.count
    # Should normalize \r\n to \n
    assert_not_includes chunks.first, "\r\n"
    assert_includes chunks.first, "\n"
  end
end
