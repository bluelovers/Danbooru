require File.dirname(__FILE__) + '/../test_helper'

class BannedIpTest < ActiveSupport::TestCase
  fixtures :users

  def setup
    @test_number = 1
  end

  def test_count_users_by_ip_addr
    post = create_post()
    comment = create_comment(post, :ip_addr => "1.2.3.4", :body => "aaa")
    counts = BannedIp.count_users_by_ip_addr("comments", [comment.user_id])
    assert_equal([{"ip_addr" => "1.2.3.4", "count" => "1"}], counts)
  end
  
  def test_count_ip_addrs_by_user
    post = create_post(:user_id => 1)
    comment = create_comment(post, :user_id => 2, :body => "aaa")
    counts = BannedIp.count_ip_addrs_by_user("comments", ["127.0.0.1"])
    assert_equal([{"count" => "1", "user_id" => "2"}], counts)
  end
  
  def test_search_users
    post = create_post()
    comment = create_comment(post, :ip_addr => "1.2.3.4", :body => "aaa")
    counts = BannedIp.search_users([comment.user_id])
    assert_equal([{"ip_addr" => "1.2.3.4", "count" => "1"}], counts["comments"])
    assert_equal([{"ip_addr" => "127.0.0.1", "count"=>"1"}], counts["tag_changes"])
  end
  
  def test_search_ip_addrs
    post = create_post()
    comment = create_comment(post, :user_id => 2, :body => "aaa")
    counts = BannedIp.search_ip_addrs(["127.0.0.1"])
    assert_equal([{"count"=>"1", "user_id"=>"2"}], counts["comments"])
    assert_equal([{"count"=>"1", "user_id"=>"1"}], counts["tag_changes"])
  end
end
