require File.dirname(__FILE__) + '/../test_helper'

class CommentControllerTest < ActionController::TestCase
  fixtures :users, :posts

  def setup
    @post_number = 1
  end

  def test_update
    comment = create_comment(Post.find(1), :body => "hi there")
    
    get :edit, {:id => comment.id}
    assert_response :success
    
    post :update, {:id => comment.id, :comment => {:body => "muggle"}}, {:user_id => 1}
    assert_redirected_to :controller => "comment", :action => "index"
    comment.reload
    assert_equal("muggle", comment.body)
    
    # TODO: test privileges
  end
  
  def test_destroy
    comment = create_comment(Post.find(1), :body => "hi there")

    post :destroy, {:id => comment.id}, {:user_id => 1}
    assert_redirected_to :controller => "post", :action => "show", :id => 1
    assert_nil(Comment.find_by_id(comment.id))
    
    # TODO: Test privileges
  end
  
  def test_create_simple
    post :create, {:comment => {:post_id => 1, :body => "hoge"}}, {:user_id => 1}
    assert_redirected_to :controller => "comment", :action => "index"
    post = Post.find(1)
    assert_equal(1, post.comments.size)
    assert_equal("hoge", post.comments[0].body)
    assert_equal(1, post.comments[0].user_id)
    assert_not_nil(post.last_commented_at)
  end
  
  def test_create_throttling
    old_member_comment_limit = CONFIG["member_comment_limit"]
    CONFIG["member_comment_limit"] = 1
    create_comment(Post.find(1), :body => "c1", :user_id => 4)
    post :create, {:comment => {:post_id => 1, :body => "c2"}, :commit => "Post"}, {:user_id => 4}
    assert_redirected_to :controller => "post", :action => "show", :id => 1
    assert_equal(1, Post.find(1).comments.size)
    assert_equal("c1", Post.find(1).comments[0].body)
    CONFIG["member_comment_limit"] = old_member_comment_limit
  end
  
  def test_create_do_not_bump_post
    post :create, {:comment => {:post_id => 1, :body => "hoge"}, :commit => "Post without bumping"}, {:user_id => 1}
    assert_redirected_to :controller => "comment", :action => "index"
    post = Post.find(1)
    assert_equal(1, post.comments.size)
    assert_nil(post.last_commented_at)
  end
  
  def test_show
    comment = create_comment(Post.find(1), :body => "hoge")
    get :show, {:id => comment.id}, {:user_id => 4}
    assert_response :success
  end
  
  def test_index
    create_comment(Post.find(1), :body => "hoge")
    create_comment(Post.find(1), :body => "moogle")
    create_comment(Post.find(3), :body => "box")
    create_comment(Post.find(2), :body => "tree")
    get :index, {}, {:user_id => 4}
    assert_response :success
  end

  def test_vote
    comment = create_comment(Post.find(1), :body => "hoge")
    
    post :vote, {:id => comment.id, :score => "up", :format => "json"}, {:user_id => 4}
    assert_response :success
    comment.reload
    assert_equal(1, comment.score)
    assert_equal(4, comment.last_voted_by)
    
    post :vote, {:id => comment.id, :score => "down", :format => "json"}, {:user_id => 4}
    assert_response 423
    comment.reload
    assert_equal(1, comment.score)
    assert_equal(4, comment.last_voted_by)
  end
  
  def test_index_hidden_and_index_all
    create_comment(Post.find(1), :body => "hoge")
    create_comment(Post.find(1), :body => "moogle")
    create_comment(Post.find(3), :body => "box")
    create_comment(Post.find(2), :body => "tree")
    
    get :index_hidden, {:post_id => 1, :format => "js"}, {:user_id => 4}
    assert_response :success

    get :index_all, {:post_id => 1, :format => "js"}, {:user_id => 4}
    assert_response :success
    
  end
end
