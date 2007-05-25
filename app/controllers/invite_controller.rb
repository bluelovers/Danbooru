class InviteController < ApplicationController
	layout "default"
	verify :method => :post, :only => [:create, :destroy]
	before_filter :user_only, :only => [:create, :destroy]

	def self.generate_activation_key
		return Digest::SHA1.hexdigest(rand().to_s)
	end

	def destroy
		@invite = Invite.find(params[:id])
		if @invite.user_id != @current_user.id
			access_denied()
		else
			@invite.destroy
			@current_user.increment!(:invite_count)
			redirect_to :controller => "user", :action => "invites"
		end
	end

	def create
		if @current_user.invite_count == 0
			respond_to do |fmt|
				fmt.html {flash[:notice] = "You do not have any invites"; redirect_to(:controller => "user", :action => "invites")}
			end
		else
			@current_user.decrement! :invite_count
			invite = Invite.create(:user_id => @current_user.id, :activation_key => self.class.generate_activation_key, :email => params[:email])
			UserMailer.deliver_new_invite(@current_user, params[:email], invite)

			respond_to do |fmt|
				fmt.html {flash[:notice] = "Your invite was mailed"; redirect_to(:controller => "user", :action => "invites")}
			end
		end
	end

	def activate
		@invite = Invite.find(params[:id])
		if @invite.activation_key != params[:key]
			access_denied()
		end
	end
end if CONFIG["enable_invites"]

