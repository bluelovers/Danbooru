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

	def self.updated_since?(date)
		fp = ForumPost.find(:first, :order => "created_at DESC")
		return fp != nil && fp.created_at > date
	end
end
