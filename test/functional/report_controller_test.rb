require File.dirname(__FILE__) + '/../test_helper'

class ReportControllerTest < ActionController::TestCase
  fixtures :users
  
  def setup
    @test_number = 1
  end
  
  def test_tag_updates
    p1 = default_create_post("hoge")
    default_update_post(p1, :tags => "moge")
    
    get :tag_updates, {}, {}
    assert_response :success
  end
  
  def test_note_updates
    n1 = default_create_note(:body => "hoge")
    n1.update_attributes(:body => "moge")
    
    get :note_updates, {}, {}
    assert_response :success
  end
  
  def test_wiki_updates
    w1 = default_create_wiki
    w1.update_attributes(:body => "moge")
    
    get :wiki_updates, {}, {}
    assert_response :success
  end
  
  def test_post_uploads
    p1 = default_create_post("hoge")
    default_update_post(p1, :tags => "moge")
    
    get :post_uploads, {}, {}
    assert_response :success
  end
end
