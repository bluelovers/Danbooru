require File.dirname(__FILE__) + '/../test_helper'

class ForumPostTest < ActiveSupport::TestCase
  fixtures :users
  
  def test_parents
    topic = ForumPost.create(:creator_id => 1, :body => "hello", :title => "hi 2 u", :last_updated_by => 1)
    assert_equal(true, topic.is_parent?)
    assert_equal(topic.id, topic.root_id)
    
    resp1 = ForumPost.create(:creator_id => 2, :body => "orly", :title => "", :parent_id => topic.id)
    topic.reload
    assert_equal(true, topic.is_parent?)
    assert_equal(false, resp1.is_parent?)
    assert_equal(1, topic.response_count)
    assert_equal(0, resp1.response_count)
    assert_equal(topic.id, topic.root_id)
    assert_equal(topic.id, resp1.root_id)
    assert_equal(resp1.creator_id, topic.last_updated_by)
    
    resp2 = ForumPost.create(:creator_id => 3, :body => "yarly", :title => "", :parent_id => topic.id)
    topic.reload
    assert_equal(2, topic.response_count)
    assert_equal(resp2.creator_id, topic.last_updated_by)
    
    resp1.reload
    resp1.destroy
    topic.reload
    assert_equal(1, topic.response_count)
  end
  
  def test_api
    topic = ForumPost.create(:creator_id => 1, :body => "hello", :title => "hi 2 u", :last_updated_by => 1)
    assert_nothing_raised do
      topic.to_json
    end
    assert_nothing_raised do
      topic.to_xml
    end
  end
  
  def test_locking
    topic = ForumPost.create(:creator_id => 1, :body => "hello", :title => "hi 2 u", :last_updated_by => 1)
    assert_equal(false, topic.is_locked?)
    ForumPost.lock!(topic.id)
    topic.reload
    assert_equal(true, topic.is_locked?)
    topic.update_attributes(:body => "bumbleclot")
    topic.reload
    assert_equal("hello", topic.body)
    ForumPost.unlock!(topic.id)
    topic.reload
    assert_equal(false, topic.is_locked?)
  end
  
  def test_sticky
    topic = ForumPost.create(:creator_id => 1, :body => "hello", :title => "hi 2 u", :last_updated_by => 1)
    assert_equal(false, topic.is_sticky?)
    ForumPost.stick!(topic.id)
    topic.reload
    assert_equal(true, topic.is_sticky?)
    ForumPost.unstick!(topic.id)
    topic.reload
    assert_equal(false, topic.is_sticky?)
    
    # Test stickying/unstickying a locked post
    ForumPost.lock!(topic.id)
    ForumPost.stick!(topic.id)
    topic.reload
    assert_equal(true, topic.is_sticky?)
    ForumPost.unstick!(topic.id)
    topic.reload
    assert_equal(false, topic.is_sticky?)
  end
end
