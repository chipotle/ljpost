require 'test/unit'
require 'ljclient'

class LjclientTest < Test::Unit::TestCase
  def test_bool
    assert_equal bool('y'), true
    assert_equal bool('yes'), true
    assert_equal bool('on'), true
    assert_equal bool('t'), true
    assert_equal bool('true'), true
    assert_equal bool('n'), false
    assert_equal bool('no'), false
    assert_equal bool('off'), false
    assert_equal bool('f'), false
    assert_equal bool('false'), false
    assert_equal bool(''), nil
    assert_equal bool('banana'), nil
  end

  def test_login
    s = LiveJournal::Client.new('www.livejournal.com')
    assert_raise LiveJournal::LjException do
      s.login('test', 'banana')
    end
  end

  # Okay, this is a LOUSY test suite. But here's the thing: there's no
  # LiveJournal test server anymore,  which makes it very difficult to
  # write tests for the actual posting/editing functionality. I'll look
  # into ways around that. Eventually.
end