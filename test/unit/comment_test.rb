require File.dirname(__FILE__) + '/../test_helper'

class CommentTest < ActiveSupport::TestCase
  fixtures :users, :posts
  
  def setup
    if CONFIG["enable_caching"]
      MEMCACHE.flush_all
    end
  end
  
  def test_simple
    comment = Comment.new(:body => "hello world")
    comment.post_id = 1
    comment.user_id = 1
    comment.ip_addr = "127.0.0.1"
    comment.save
    assert_equal("admin", comment.author)
    assert_equal("hello world", comment.body)
    assert_equal(comment.created_at.to_s, Post.find(1).last_commented_at.to_s)
  end
  
  def test_no_bump
    comment = Comment.new(:do_not_bump_post => "1", :body => "hello world")
    comment.post_id = 1
    comment.user_id = 1
    comment.ip_addr = "127.0.0.1"
    comment.save
    assert_equal("admin", comment.author)
    assert_equal("hello world", comment.body)
    assert_nil(Post.find(1).last_commented_at)
  end

  def test_threshold
    old_threshold = CONFIG["comment_threshold"]
    CONFIG["comment_threshold"] = 1
    
    comment_a = Comment.new(:body => "mark 1")
    comment_a.post_id = 1
    comment_a.user_id = 1
    comment_a.ip_addr = "127.0.0.1"
    comment_a.save
    sleep 1
    comment_b = Comment.new(:body => "mark 2")
    comment_b.post_id = 1
    comment_b.user_id = 1
    comment_b.ip_addr = "127.0.0.1"
    comment_b.save
    assert_equal(comment_a.created_at.to_s, Post.find(1).last_commented_at.to_s)
    
    CONFIG["comment_threshold"] = old_threshold
  end
  
  def test_api
    comment = Comment.new(:body => "hello world")
    comment.post_id = 1
    comment.user_id = 1
    comment.ip_addr = "127.0.0.1"
    comment.save
    
    assert_nothing_raised do
      comment.to_xml
    end
    assert_nothing_raised do
      comment.to_json
    end
  end
end
