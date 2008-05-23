require File.dirname(__FILE__) + '/../test_helper'

class WikiPageTest < ActiveSupport::TestCase
  def setup
    if CONFIG["enable_caching"]
      CACHE.flush_all
    end
  end
  
  def create_wiki(params = {})
    WikiPage.create({:title => "hoge", :user_id => 1, :body => "hoge", :ip_addr => "127.0.0.1", :is_locked => false}.merge(params))
  end
  
  def update_wiki(w1, params = {})
    w1.update_attributes(params)
  end
  
  def test_normalize
    w1 = create_wiki(:title => "HOT POTATO")
    assert_equal("hot_potato", w1.title)
  end
  
  def test_diff
    raise NotImplementedError
  end
  
  def test_find_page
    w1 = create_wiki
    update_wiki(w1, :body => "moge")
    update_wiki(w1, :body => "moge moge")
    
    w1 = WikiPage.find_page("hoge", 1)
    assert_equal("hoge", w1.body)
    
    w1 = WikiPage.find_page("hoge", 2)
    assert_equal("moge", w1.body)
    
    w1 = WikiPage.find_page("hoge", 3)
    assert_equal("moge moge", w1.body)
  end
  
  def test_lock
    w1 = create_wiki
    update_wiki(w1, :body => "moge")
    update_wiki(w1, :body => "moge moge")

    w1.lock!
    assert_equal(true, w1.is_locked?)
    assert_equal(true, WikiPageVersion.find(:first, :conditions => ["wiki_page_id = ? AND version = 1", w1.id]).is_locked?)
    assert_equal(true, WikiPageVersion.find(:first, :conditions => ["wiki_page_id = ? AND version = 2", w1.id]).is_locked?)
    
    w1.unlock!
    assert_equal(false, w1.is_locked?)
    assert_equal(false, WikiPageVersion.find(:first, :conditions => ["wiki_page_id = ? AND version = 1", w1.id]).is_locked?)
    assert_equal(false, WikiPageVersion.find(:first, :conditions => ["wiki_page_id = ? AND version = 2", w1.id]).is_locked?)
  end
  
  def test_rename
    w1 = create_wiki
    update_wiki(w1, :body => "moge")
    update_wiki(w1, :body => "moge moge")

    w1.rename!("shalala")
    assert_not_nil(WikiPageVersion.find_by_title("shalala"))
  end
  
  def test_api
    w1 = create_wiki
    assert_nothing_raised(Exception) { w1.to_json }
    assert_nothing_raised(Exception) { w1.to_xml }
  end
end
