require File.dirname(__FILE__) + '/../test_helper'

class ModQueuePostTest < ActiveSupport::TestCase
  fixtures :users, :posts, :mod_queue_posts
  
  def test_reject_hidden
    posts = Post.find(:all, :order => "id")
    assert_equal([1, 2, 3, 4, 5], posts.map(&:id))
    posts = ModQueuePost.reject_hidden(posts, User.find(1))
    assert_equal([2, 3, 4, 5], posts.map(&:id))
  end
  
  def test_prune
    Post.update(2, :status => "pending")
    assert_equal(2, ModQueuePost.count)
    ModQueuePost.prune!
    assert_equal(1, ModQueuePost.count)
  end
end
