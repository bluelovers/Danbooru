require File.dirname(__FILE__) + '/../test_helper'

class PostAppealTest < ActiveSupport::TestCase
  fixtures :users
  
  def setup
    @test_number = 1
    @user = User.find(1)
    @posts = []
    @posts << create_post("tag", :file => upload_jpeg("#{RAILS_ROOT}/test/mocks/test/test1.jpg"))
    @posts << create_post("tag", :file => upload_jpeg("#{RAILS_ROOT}/test/mocks/test/test2.jpg"))
    @posts << create_post("tag", :file => upload_jpeg("#{RAILS_ROOT}/test/mocks/test/test3.jpg"))
    @posts << create_post("tag", :file => upload_jpeg("#{RAILS_ROOT}/test/mocks/test/test4.jpg"))
    @posts << create_post("tag", :file => upload_jpeg("#{RAILS_ROOT}/test/mocks/test/test5.jpg"))
    @posts << create_post("tag", :file => upload_jpeg("#{RAILS_ROOT}/test/mocks/test/test6.jpg"))
  end
  
  def test_limiting
    PostAppeal.create(:user => @user, :post => @posts[0], :reason => "aaa")
    PostAppeal.create(:user => @user, :post => @posts[1], :reason => "aaa")
    PostAppeal.create(:user => @user, :post => @posts[2], :reason => "aaa")
    PostAppeal.create(:user => @user, :post => @posts[3], :reason => "aaa")
    PostAppeal.create(:user => @user, :post => @posts[4], :reason => "aaa")
    @appeal = PostAppeal.create(:user => @user, :post => @posts[5], :reason => "aaa")
    assert_equal(["User can only appeal 5 posts a day"], @appeal.errors.full_messages)
  end
end
