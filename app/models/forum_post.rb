class ForumPost < ActiveRecord::Base
	has_many :children, :class_name => "ForumPost", :foreign_key => :parent_id
	belongs_to :parent, :class_name => "ForumPost", :foreign_key => :parent_id
	belongs_to :creator, :class_name => "User", :foreign_key => :user_id
	before_create :update_parent
	validates_length_of :title, :minimum => 1, :message => "You need to enter a title"
	validates_format_of :title, :with => /\S/, :message => "You need to enter a title"
	validates_length_of :body, :minimum => 1, :message => "You need to enter a message"

	def update_parent
		unless self.parent?
			p = self.parent
			p.update_attribute(:updated_at, Time.now)
		end
	end

	def parent?
		return self.parent_id == nil
	end

	def view_id
		if self.parent?
			return self.id
		else
			return self.parent_id
		end
	end

	def author
		self.creator.name
	end
end
