class TestJanitorController < ApplicationController
  before_filter :admin_only
  layout "default"
  
  def index
    @users = User.all(:conditions => "level = 34", :order => "name")
  end
  
  def new
  end
  
  def create
    @user = User.find_by_name(params[:name])
    TestJanitor.create(
      :user_id => @user.id,
      :test_promotion_date => Time.now,
      :original_level => @user.level
    )
    @user.level = CONFIG["user_levels"]["Test Janitor"]
    @user.save
    flash[:notice] = "User was promoted to test janitor"
    redirect_to :action => "index"
  end
  
  def promote
    @janitor = TestJanitor.find(params[:id])
    @janitor.update_attribute(:promotion_date, Time.now)
    x = @janitor.user
    x.level = CONFIG["user_levels"]["Janitor"]
    x.save
    flash[:notice] = "User was promoted to janitor"
    redirect_to :action => "index"
  end
  
  def demote
    @janitor = TestJanitor.find(params[:id])
    x = @janitor.user
    x.level = @janitor.original_level
    x.save
    UserRecord.create(
      :user_id => @janitor.user_id,
      :reported_by => @current_user.id,
      :score => 0,
      :body => "Demoted from test janitor position"
    )
    @janitor.destroy
    flash[:notice] = "User was demoted"
    redirect_to :action => "index"
  end
  
  def test
    @user = User.find_by_name(params[:name])
    render :layout => false
  end
  
  def approvals
    @janitor = TestJanitor.find(params[:id])
    @posts = Post.paginate(:conditions => ["posts.approver_id =?", @janitor.user_id], :order => "id desc", :per_page => 20, :page => params[:page])
  end
end
