require File.dirname(__FILE__) + '/../test_helper'

class ArtistTest < ActiveSupport::TestCase
  fixtures :users
  
  def setup
    if CONFIG["enable_caching"]
      MEMCACHE.flush_all
    end
  end
  
  def test_normalize
    artist = create_artist(:name => "pierre")
    assert_equal("pierre", artist.name)
    
    # Test downcasing of name
    artist = create_artist(:name => "JACQUES")
    assert_equal("jacques", artist.name)
    
    # Delete leading and trailing whitespace
    artist = create_artist(:name => " monet ")
    assert_equal("monet", artist.name)
    
    # Convert whitespace to underscores
    artist = create_artist(:name => "takashi takeuchi")
    assert_equal("takashi_takeuchi", artist.name)
  end
  
  def test_ambiguous_urls
    bobross = create_artist(:name => "bob_ross", :urls => "http://artists.com/bobross/image.jpg")
    bob = create_artist(:name => "bob", :urls => "http://artists.com/bob/image.jpg")
    matches = Artist.find_all_by_url("http://artists.com/bob/test.jpg")
    assert_equal(1, matches.size)
    assert_equal("bob", matches.first.name)
  end
  
  def test_urls
    artist = create_artist(:name => "rembrandt", :urls => "http://rembrandt.com/test.jpg")
    artist.reload
    assert_equal(["http://rembrandt.com/test.jpg"], artist.urls.split.sort)

    # Make sure old URLs are deleted, and make sure the artist understands multiple URLs
    update_artist(artist, :urls => "http://not.rembrandt.com/test.jpg\nhttp://also.not.rembrandt.com/test.jpg")
    artist.reload
    assert_equal(["http://also.not.rembrandt.com/test.jpg", "http://not.rembrandt.com/test.jpg"], artist.urls.split.sort)

    # Test Artist.find_all_by_url
    assert_equal(["rembrandt"], Artist.find_all_by_url("http://also.not.rembrandt.com/test.jpg").map(&:name))
    assert_equal(["rembrandt"], Artist.find_all_by_url("http://also.not.rembrandt.com/another.jpg").map(&:name))    
    assert_equal(["rembrandt"], Artist.find_all_by_url("http://not.rembrandt.com/another.jpg").map(&:name))    
    assert_equal([], Artist.find_all_by_url("http://nonexistent.rembrandt.com/test.jpg").map(&:name))

    # Make sure duplicates are removed
    create_artist(:name => "warhol", :urls => "http://warhol.com/a/image.jpg\nhttp://warhol.com/b/image.jpg")
    assert_equal(["warhol"], Artist.find_all_by_url("http://warhol.com/test.jpg").map(&:name))
    
    # Make sure deleted artists are hidden
    artist.update_attribute(:is_active, false)
    assert_equal([], Artist.find_all_by_url("http://also.not.rembrandt.com/test.jpg").map(&:name))    
  end
  
  def test_other_names
    assert_nil(Artist.find_by_name("other:aaa"))
    
    a1 = create_artist(:name => "a1", :other_names => "aaa, bbb, ccc ddd")
    
    assert_nil(Artist.find_by_name("name:aaa"))
    assert_nil(Artist.find_by_name("name:bbb"))
    assert_nil(Artist.find_by_name("name:ccc_ddd"))
    
    a1.reload
    
    assert_equal("aaa, bbb, ccc_ddd", a1.other_names)
    assert_equal("{aaa,bbb,ccc_ddd}", a1.other_names_array)
    assert_not_nil(Artist.find_by_name("other:aaa"))
    
    # Test special characters
    a1.update_attributes(:other_names => "\\, \", '")
    a1.reload
    assert_equal("\\, \", '", a1.other_names)
    assert_equal("{\"\\\\\",\"\\\"\",'}", a1.other_names_array)
  end

  def test_groups
    assert_nil(Artist.find_by_name("group:cat_or_fish"))
    cat_or_fish = create_artist(:name => "cat_or_fish")
    yuu = create_artist(:name => "yuu", :group_name => "cat_or_fish")
    cat_or_fish.reload
    assert_equal("yuu", cat_or_fish.member_names)
    assert_not_nil(Artist.find_by_name("group:cat_or_fish"))
  end
  
  def test_api
    boss = create_artist(:name => "boss")
    assert_nothing_raised do
      boss.to_xml
    end
    assert_nothing_raised do
      boss.to_json
    end
  end
  
  def test_notes
    hoge = create_artist(:name => "hoge", :notes => "this is hoge")
    assert_not_nil(WikiPage.find_by_title("hoge"))
    assert_equal("this is hoge", WikiPage.find_by_title("hoge").body)
    
    update_artist(hoge, :notes => "this is hoge mark ii")
    assert_equal("this is hoge mark ii", WikiPage.find_by_title("hoge").body)
    
    WikiPage.find_by_title("hoge").lock!
    update_artist(hoge, :notes => "this is hoge mark iii")
    assert_equal("this is hoge mark ii", WikiPage.find_by_title("hoge").body)
  end
end
