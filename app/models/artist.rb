class Artist < ActiveRecord::Base
  before_validation :normalize
  validates_uniqueness_of :name
  after_save :commit_relations
  after_save :commit_notes
  belongs_to :updater, :class_name => "User", :foreign_key => "updater_id"
  attr_accessor :updater_ip_addr

  def self.normalize_url(url)
    if url
      url = url.gsub(/\/$/, "")
      url = url.gsub(/^http:\/\/blog\d+\.fc2/, "http://blog.fc2")
      url = url.gsub(/^http:\/\/blog-img-\d+\.fc2/, "http://blog.fc2")
      return url
    else
      return nil
    end
  end

  def normalize
    self.name = self.name.downcase.gsub(/^\s+/, "").gsub(/\s+$/, "").gsub(/ /, '_')
    self.url_a = self.class.normalize_url(self.url_a)
    self.url_b = self.class.normalize_url(self.url_b)
    self.url_c = self.class.normalize_url(self.url_c)
  end

  def commit_relations
    transaction do
      connection.execute("UPDATE artists SET alias_id = NULL WHERE alias_id = #{self.id}")
      connection.execute("UPDATE artists SET group_id = NULL WHERE group_id = #{self.id}")

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
  end
  
  def commit_notes
    unless @notes.blank?
      wp = WikiPage.find_by_title(self.name)
      
      if wp == nil
        wp = WikiPage.create(:title => self.name, :body => @notes, :ip_addr => updater_ip_addr, :user_id => updater_id)
      elsif wp.is_locked?
        self.errors.add(:notes, "wiki page is locked")
      else
        wp.update_attributes(:body => @notes, :ip_addr => updater_ip_addr, :user_id => updater_id)
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
      begin
        return Artist.find(self.alias_id).name
      rescue ActiveRecord::RecordNotFound
      end
    end
    
    return nil
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
    {:id => id, :name => name, :alias_id => alias_id, :group_id => group_id, :url_a => url_a, :url_b => url_b, :url_c => url_c}.to_xml(options.merge(:root => "artist"))
  end

  def to_json(options = {})
    {:id => id, :name => name, :alias_id => alias_id, :group_id => group_id, :url_a => url_a, :url_b => url_b, :url_c => url_c}.to_json(options)
  end

  def to_s
    return self.name
  end
  
  def notes
    wp = WikiPage.find_page(self.name)
    
    if wp
      return wp.body
    else
      return ""
    end
  end
  
  def notes=(val)
    @notes = val
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
    url = normalize_url(url)
    artists = []

    while artists.empty? && url.size > 10
      u = url.to_escaped_for_sql_like.gsub(/\*/, '%') + '%'
      artists += Artist.find(:all, :conditions => ["url_a LIKE ? ESCAPE '\\\\' OR url_b LIKE ? ESCAPE '\\\\' OR url_c LIKE ? ESCAPE '\\\\'", u, u, u], :order => "name")
      url = File.dirname(url)
    end

    return artists[0, 10]
  end
end
