class Artist < ActiveRecord::Base
	before_save :normalize
	validates_uniqueness_of :name

	def normalize
		self.name = self.name.downcase.gsub(/ /, '_')

		self.url_a.gsub!(/\/$/, "") if self.url_a
		self.url_b.gsub!(/\/$/, "") if self.url_b
		self.url_c.gsub!(/\/$/, "") if self.url_c
	end

	def aliases
		return Artist.find(:all, :conditions => "alias_id = #{self.id}", :order => "name")
	end

	def alias
		if self.alias_id
			return Artist.find(self.alias_id).name
		else
			nil
		end
	end

	def alias=(n)
		return if n.blank?
		a = Artist.find_or_create_by_name(n)
		self.alias_id = a.id
	end

	def group
		if self.group_id
			return Artist.find(self.group_id).name
		else
			nil
		end
	end

	def members
		Artist.find(:all, :conditions => "group_id = #{self.id}", :order => "name")
	end

	def group=(n)
		return if n.blank?
		a = Artist.find_or_create_by_name(n)
		self.group_id = a.id
	end

	def to_json(options = {})
		{:id => self.id, :name => self.name, :alias_id => self.alias_id, :group_id => self.group_id, :url_a => self.url_a, :url_b => self.url_b, :url_c => self.url_c}.to_json(options)
	end
end
