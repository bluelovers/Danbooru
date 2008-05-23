require File.dirname(__FILE__) + '/../test_helper'

class DmailTest < ActiveSupport::TestCase
  fixtures :users
  
  def setup
    if CONFIG["enable_caching"]
      CACHE.flush_all
    end
    
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []
  end
  
  def test_all
    msg = Dmail.create(:to_name => "member", :from_name => "admin", :title => "hello", :body => "hello")
    assert_equal(4, msg.to_id)
    assert_equal(1, msg.from_id)
    assert_equal(true, User.find(4).has_mail?)
    assert_equal(1, ActionMailer::Base.deliveries.size)
    assert_equal("To: member@danbooru.com\r\nSubject: #{CONFIG['app_name']} - Message received from admin\r\nMime-Version: 1.0\r\nContent-Type: text/html; charset=utf-8\r\n\r\n<p>admin said:</p>\n\n<div>\n  hello\n</div>\n", ActionMailer::Base.deliveries[0].encoded)
    
    response_a = Dmail.create(:to_name => "admin", :from_name => "member", :parent_id => msg.id, :title => "hello", :body => "you are wrong")
    assert_equal("Re: hello", response_a.title)
    
    ActionMailer::Base.deliveries = []
    
    Dmail.create(:to_name => "privileged", :from_name => "admin", :title => "hoge", :body => "hoge")
    assert_equal(0, ActionMailer::Base.deliveries.size)
  end
end
