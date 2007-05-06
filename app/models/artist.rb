class Artist < ActiveRecord::Base
	before_save :normalize
	after_save :commit_relations
	validates_uniqueness_of :name

	def normalize
		self.name = self.name.downcase.gsub(/ /, '_')

		self.url_a.gsub!(/\/$/, "") if self.url_a
		self.url_b.gsub!(/\/$/, "") if self.url_b
		self.url_c.gsub!(/\/$/, "") if self.url_c
	end

	def commit_relations
		self.aliases.each do |a|
			a.update_attribute(:alias_id, nil)
		end

		self.members.each do |m|
			m.update_attribute(:group_id, nil)
		end

		if @cached_aliases && @cached_aliases.any?
			@cached_aliases.each do |name|
				a = Artist.find_or_create_by_name(name.downcase.gsub(/ /, '_'))
				a.update_attribute(:alias_id, self.id)
			end
		end

		if @cached_members && @cached_members.any?
			@cached_members.each do |name|
				a = Artist.find_or_create_by_name(name.downcase.gsub(/ /, '_'))
				a.update_attribute(:group_id, self.id)
			end
		end
	end

	def aliases=(names)
		@cached_aliases = names.split(/\s*,\s*/)
	end

	def members=(names)
		@cached_members = names.split(/\s*,\s*/)
	end

	def aliases
		if self.new_record?
			return []
		else
			return Artist.find(:all, :conditions => "alias_id = #{self.id}", :order => "name")
		end
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
		if self.new_record?
			return []
		else
			Artist.find(:all, :conditions => "group_id = #{self.id}", :order => "name")
		end
	end

	def group=(n)
		return if n.blank?
		a = Artist.find_or_create_by_name(n)
		self.group_id = a.id
	end

	def to_json(options = {})
		{:id => self.id, :name => self.name, :alias_id => self.alias_id, :group_id => self.group_id, :url_a => self.url_a, :url_b => self.url_b, :url_c => self.url_c}.to_json(options)
	end

	def to_s
		return self.name
	end
end
