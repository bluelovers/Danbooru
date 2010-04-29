require File.dirname(__FILE__) + '/../test_helper'

class BannedIpTest < ActiveSupport::TestCase
  fixtures :users

  def setup
    @test_number = 1
  end

  def test_count_by_ip_addr
    post = create_post()
    comment = create_comment(post, :ip_addr => "1.2.3.4", :body => "aaa")
    counts = BannedIp.count_by_ip_addr("comments", [comment.user_id])
    assert_equal([{"ip_addr" => "1.2.3.4", "count" => "1"}], counts)
  end
  
  def test_search
    post = create_post()
    comment = create_comment(post, :ip_addr => "1.2.3.4", :body => "aaa")
    counts = BannedIp.search([comment.user_id])
    assert_equal([{"ip_addr" => "1.2.3.4", "count" => "1"}], counts["comments"])
  end
end
