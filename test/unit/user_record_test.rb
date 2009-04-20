require File.dirname(__FILE__) + '/../test_helper'

class UserRecordTest < ActiveSupport::TestCase
  def setup
    MEMCACHE.flush_all
  end

  def test_all
    dmail = UserRecord.create(:body => "bad", :user => "member", :reported_by => 1, :is_positive => true)
    assert_equal(4, dmail.user_id)
    assert_not_nil(Dmail.find_by_body("admin created a positive record for your account."))
  end
end
