class Artist < ActiveRecord::Base
  default_scope :select => "artists.*, coalesce(array_to_string(other_names_array, ', '), '') AS other_names_string"

  include ArtistMethods::UrlMethods
  include ArtistMethods::NoteMethods
  include ArtistMethods::OtherNameMethods
  include ArtistMethods::GroupMethods
  include ArtistMethods::ApiMethods
  include ArtistMethods::VersionMethods
  
  before_validation :normalize
  validates_uniqueness_of :name
  belongs_to :updater, :class_name => "User", :foreign_key => "updater_id"
  attr_accessor :updater_ip_addr
  has_many :members, :class_name => "Artist", :foreign_key => "group_name", :primary_key => "name"

  def self.normalize(name)
    name.downcase.strip.gsub(/ /, '_')
  end

  def normalize
    self.name = Artist.normalize(name)
  end
  
  def to_s
    return name
  end
  
  def updater_name
    User.find_name(updater_id).tr("_", " ")
  end
  
  def has_tag_alias?
    TagAlias.exists?(["name = ?", name])
  end
  
  def tag_alias_name
    TagAlias.find_by_name(name).alias_name
  end

  def self.find_by_name(name)
    first(generate_sql(:name => name))
  end
  
  def self.generate_sql(params)
    b = Nagato::Builder.new do |builder, cond|
      cond.add "is_active = TRUE"
      
      case params[:name]
      when /^http/
        cond.add "id IN (?)", find_all_by_url(params[:name]).map {|x| x.id}
      
      when /name:(.+)/
        stripped_name = Artist.normalize($1).to_escaped_for_sql_like
        cond.add "name LIKE ? ESCAPE E'\\\\'", stripped_name
        
      when /other:(.+)/
        stripped_name = Artist.normalize($1).to_escaped_for_sql_like
        cond.add "? ~~~ ANY (other_names_array)", stripped_name
        
      when /group:(.+)/
        stripped_name = Artist.normalize($1).to_escaped_for_sql_like
        cond.add "group_name LIKE ?", stripped_name
        
      when /./
        stripped_name = Artist.normalize(params[:name]).to_escaped_for_sql_like
        cond.add "name LIKE ? ESCAPE E'\\\\' OR ? ~~~ ANY (other_names_array) OR group_name LIKE ?", stripped_name, stripped_name, stripped_name
      end
      
      cond.add_unless_blank "id = ?", params[:id]
    end
    
    return b.to_hash
  end
end
