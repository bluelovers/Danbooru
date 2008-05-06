require File.dirname(__FILE__) + '/../test_helper'

class BanTest < ActiveSupport::TestCase
  fixtures :users

  def test_all
    Ban.create(:user_id => 4, :banned_by => 1, :reason => "hoge", :duration => "3")
    assert_equal(CONFIG["user_levels"]["Blocked"], User.find(4).level)
    assert_not_nil(UserRecord.find_by_user_id(4))
    assert_equal("Blocked: hoge", UserRecord.find_by_user_id(4).body)
  end
end
