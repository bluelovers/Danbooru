require File.dirname(__FILE__) + '/../test_helper'

class ArtistControllerTest < ActionController::TestCase
  fixtures :users

  def test_destroy
    artist = create_artist(:name => "bob")
    
    post :destroy, {:id => artist.id, :commit => "Yes"}, {:user_id => 1}
    assert_redirected_to :controller => "artist", :action => "index"
    bob = Artist.first(:conditions => ["name = ?", "bob"])
    assert_not_nil(bob)
    assert_equal(false, bob.is_active?)
  end
  
  def test_update_to_existing_name
    a1 = create_artist(:name => "a1", :group_name => "sam", :urls => "d e f", :other_names => "a2")
    a2 = create_artist(:name => "a2", :group_name => "bob", :urls => "a b c")
    
    post :update, {:id => a1.id, :artist => {:name => "a2", :group_name => "ted", :urls => "x y z", :other_names => "a3"}}, {:user_id => 4}
    a1 = Artist.find(a1.id)
    a2 = Artist.find(a2.id)
    
    assert_equal(false, a1.is_active?)
    assert_equal(true, a2.is_active?)
    assert_equal("a1", a1.name)
    assert_equal("a2", a2.name)
    assert_equal("d\ne\nf", a1.urls)
    assert_equal("x\ny\nz", a2.urls)
    assert_equal("sam", a1.group_name)
    assert_equal("ted", a2.group_name)
    assert_equal("a2", a1.other_names)
    assert_equal("a3", a2.other_names)
  end
  
  def test_update
    artist = create_artist(:name => "bob")
    
    get :update, {:id => artist.id}, {:user_id => 4}
    assert_response :success

    post :update, {:id => artist.id, :artist => {:name => "monet", :urls => "http://monet.com/home\nhttp://monet.com/links\n", :other_names => "claude, oscar", :group_name => "john", :notes => "Claude Oscar Monet"}}, {:user_id => 4}
    artist = Artist.find(artist.id)
    assert_equal("monet", artist.name)
    monet = Artist.find_by_name("monet")
    assert_not_nil(monet)
    assert_equal(artist.id, monet.id)
    assert_redirected_to :controller => "artist", :action => "show", :id => monet.id
    
    assert_equal("claude, oscar", monet.other_names)
    assert_equal(["http://monet.com/home", "http://monet.com/links"], monet.artist_urls.map(&:url).sort)
    
    post :update, {:id => artist.id, :artist => {}}, {:user_id => 4}
    artist = Artist.find(artist.id)
    assert_equal("claude, oscar", artist.other_names)
    assert_equal("john", artist.group_name)
    
    post :update, {:id => artist.id, :artist => {:other_names => ""}}, {:user_id => 4}
    artist = Artist.find(artist.id)
    assert_equal("", artist.other_names)
  end
  
  def test_create
    get :create, {}, {:user_id => 4}
    assert_response :success
    
    post :create, {:artist => {:name => "monet", :urls => "http://monet.com/home\nhttp://monet.com/links\n", :other_names => "claude, oscar", :group_name => "john", :notes => "Claude Oscar Monet"}}, {:user_id => 4}
    monet = Artist.find_by_any_name("monet")
    assert_not_nil(monet)
    assert_redirected_to :controller => "artist", :action => "show", :id => monet.id
    assert_equal(["http://monet.com/home", "http://monet.com/links"], monet.artist_urls.map(&:url).sort)
  end
  
  def test_show
    monet = create_artist(:name => "monet")
    get :show, {:id => monet.id}
    assert_response :success
  end
  
  def test_index
    create_artist(:name => "monet")
    create_artist(:name => "pablo", :other_names => "monet")
    create_artist(:name => "hanaharu", :group_name => "monet")
    get :index
    assert_response :success
    
    # TODO: add additional cases
  end
end
