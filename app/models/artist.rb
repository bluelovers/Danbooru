class Artist < ActiveRecord::Base
	before_save :normalize
	after_save :commit_relations
	validates_uniqueness_of :name
	belongs_to :updater, :class_name => "User", :foreign_key => "updater_id"

	def normalize
    self.name = self.name.downcase.gsub(/^\s+/, "").gsub(/\s+$/, "").gsub(/ /, '_')
		self.url_a = self.url_a.gsub(/\/$/, "") if self.url_a
		self.url_b = self.url_b.gsub(/\/$/, "") if self.url_b
		self.url_c = self.url_c.gsub(/\/$/, "") if self.url_c
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
				a = Artist.find_or_create_by_name(name)
				a.update_attributes(:alias_id => self.id, :updater_id => self.updater_id)
			end
		end

		if @cached_members && @cached_members.any?
			@cached_members.each do |name|
				a = Artist.find_or_create_by_name(name)
				a.update_attributes(:group_id => self.id, :updater_id => self.updater_id)
			end
		end
	end

	def aliases=(names)
		@cached_aliases = names.scan(/\s*,\s*/)
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
		if n.blank?
			self.alias_id = nil
		else
			a = Artist.find_or_create_by_name(n)
			self.alias_id = a.id
		end
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
		if n.blank?
			self.group_id = nil
		else
			a = Artist.find_or_create_by_name(n)
			self.group_id = a.id
		end
	end

  def to_xml(options = {})
    {:id => id, :name => name, :alias_id => alias_id, :group_id => group_id, :url_a => url_a, :url_b => url_b, :url_c => url_c}.to_xml("artist", options)
  end

	def to_json(options = {})
		{:id => id, :name => name, :alias_id => alias_id, :group_id => group_id, :url_a => url_a, :url_b => url_b, :url_c => url_c}.to_json(options)
	end

	def to_s
		return self.name
	end

  def self.find_all_by_md5(md5)
    p = Post.find_by_md5(md5)

    if p == nil
      return []
    else
      artist_type = Tag.types[:artist]
      artists = p.tags.select {|x| x.tag_type == artist_type}.map {|x| x.name}
      return Artist.find_all_by_name(artists)
    end
  end

  def self.find_all_by_url(url)
    artists = []

    while artists.empty? && url.size > 10
      puts url
      u = url.to_escaped_for_sql_like + '%'
      artists += Artist.find(:all, :conditions => ["url_a LIKE ? ESCAPE '\\\\' OR url_b LIKE ? ESCAPE '\\\\' OR url_c LIKE ? ESCAPE '\\\\'", u, u, u], :order => "name")
      url = File.dirname(url)
    end

    return artists
  end
end
