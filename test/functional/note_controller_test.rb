require File.dirname(__FILE__) + '/../test_helper'

class NoteControllerTest < ActionController::TestCase
  fixtures :users
  
  def setup_test
    @test_number = 1
    @post1 = create_post("tag1")
    @post2 = create_post("tag2")
  end
  
  def test_create
    setup_test
    
    # Assume note locking is tested in the unit tests
    post :update, {:note => {:post_id => @post1.id, :x => 100, :y => 200, :height => 300, :width => 400, :body => "moogles"}}, {:user_id => 1}
    assert_equal(1, @post1.notes.size)
    assert_equal(100, @post1.notes[0].x)
    assert_equal("moogles", @post1.notes[0].body)
    assert_equal(1, @post1.notes[0].user_id)
    
    # TODO: test privileges
  end
  
  def test_update
    setup_test
    
    note = create_note(:body => "moogles", :post_id => @post1.id)
    post :update, {:id => note.id, :note => {:body => "hoge"}}, {:user_id => 1}
    note.reload
    assert_equal("hoge", note.body)
    # TODO: test privileges
  end
  
  def test_revert
    setup_test
    
    note = create_note(:body => "hoge", :post_id => @post1.id)
    note.update_attributes(:body => "mark ii")
    note.update_attributes(:body => "mark iii")
    
    post :revert, {:id => note.id, :version => 1}, {:user_id => 1}
    note.reload
    assert_equal("hoge", note.body)
    
    post :revert, {:id => note.id, :version => 3}, {:user_id => 1}
    note.reload
    assert_equal("mark iii", note.body)
  end
  
  def test_history
    setup_test
    
    note = create_note(:body => "hoge", :post_id => @post1.id)
    
    get :history, {}, {:user_id => 1}
    assert_response :success
    
    get :history, {:id => note.id}, {:user_id => 1}
    assert_response :success
    
    get :history, {:post_id => @post1.id}, {:user_id => 1}
    assert_response :success
    
    get :history, {:user_id => 1}, {:user_id => 1}
    assert_response :success
  end
  
  def test_index
    setup_test
        
    note = create_note(:body => "hoge", :post_id => @post1.id)

    get :index, {}, {:user_id => 1}
    assert_response :success
    
    get :index, {:post_id => @post1.id}, {:user_id => 1}
    assert_response :success
  end
  
  def test_search
    setup_test
        
    note = create_note(:body => "hoge", :post_id => @post1.id)

    get :search, {}, {:user_id => 1}
    assert_response :success
    
    get :search, {:query => "hoge"}, {:user_id => 1}
    assert_response :success
  end
end
