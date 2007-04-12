class ForumPost < ActiveRecord::Base
	has_many :children, :class_name => "ForumPost", :foreign_key => :parent_id
	belongs_to :parent, :class_name => "ForumPost", :foreign_key => :parent_id
	belongs_to :creator, :class_name => "User", :foreign_key => :user_id
	before_create :update_parent
	before_validation :validate_title
	validates_length_of :body, :minimum => 1, :message => "You need to enter a message"

	def validate_title
		if self.parent?
			if self.title.blank?
				self.errors.add :title, "missing"
				return false
			end

			if self.title !~ /\S/
				self.errors.add :title, "missing"
				return false
			end
		end

		return true
	end

	def update_parent
		unless self.parent?
			p = self.parent
			p.update_attribute(:updated_at, Time.now)
		end
	end

	def updated?(user_id)
		fpv = ForumPostView.find(:first, :conditions => ["user_id = ? AND forum_post_id = ?", user_id, self.id])
		return fpv == nil || fpv.last_viewed_at < self.updated_at
	end

	def parent?
		return self.parent_id == nil
	end

	def root_id
		if self.parent?
			return self.id
		else
			return self.parent_id
		end
	end

	def author
		self.creator.name
	end

	def self.updated_since?(user_id)
		return false

		fp = ForumPostView.find(:first, :conditions => ["forum_posts_user_views.user_id = ? AND forum_posts_user_views.last_viewed_at < forum_posts.updated_at AND forum"])
		return fp != nil
	end
end
