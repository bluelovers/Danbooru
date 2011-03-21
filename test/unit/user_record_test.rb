require File.dirname(__FILE__) + '/../test_helper'

class UserRecordTest < ActiveSupport::TestCase
  def setup
    MEMCACHE.flush_all
  end

  def test_all
    dmail = UserRecord.create(:body => "bad", :user => "member", :reported_by => 1, :score => 1)
    assert_equal(4, dmail.user_id)
    assert_not_nil(Dmail.find_by_body(%{admin created a "positive record":/user_record/index?user_id=4 for your account.}))
  end
end
