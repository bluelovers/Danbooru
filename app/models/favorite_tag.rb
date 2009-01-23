class FavoriteTag < ActiveRecord::Base
  belongs_to :user
  before_create :initialize_post_ids
  before_save :normalize_name

  def normalize_name
    self.name = name.gsub(/\W/, "_")
  end
  
  def initialize_post_ids
    if user.is_privileged_or_higher?
      self.cached_post_ids = Post.find_by_tags(tag_query, :limit => 60, :select => "p.id", :order => "p.id desc").map(&:id).uniq.join(",")
    end
  end
  
  def add_posts!(post_ids)
    if cached_post_ids.blank?
      update_attribute :cached_post_ids, post_ids.join(",")
    else
      update_attribute :cached_post_ids, post_ids.join(",") + "," + cached_post_ids
    end
  end
  
  def prune!
    hoge = cached_post_ids.split(/,/)
    
    if hoge.size > CONFIG["favorite_tag_post_limit"]
      update_attribute :cached_post_ids, hoge[0, CONFIG["favorite_tag_post_limit"]].join(",")
    end
  end
  
  def self.find_post_ids(user_id, favtag_name = nil, limit = 200)
    if favtag_name
      find(:all, :conditions => ["user_id = ? AND name ILIKE ? ESCAPE E'\\\\'", user_id, favtag_name.to_escaped_for_sql_like + "%"], :select => "id, cached_post_ids").map {|x| x.cached_post_ids.split(/,/)}.flatten.uniq.slice(0, limit)
    else
      find(:all, :conditions => ["user_id = ?", user_id], :select => "id, cached_post_ids").map {|x| x.cached_post_ids.split(/,/)}.flatten.uniq.slice(0, limit)
    end
  end
  
  def self.find_posts(user_id, favtag_name = nil, limit = 60)
    Post.find(:all, :conditions => ["id in (?)", find_post_ids(user_id, favtag_name, limit)], :order => "id DESC", :limit => limit)
  end
  
  def self.process_all
    fav_tags = FavoriteTag.find(:all)
    
    fav_tags.each do |fav_tag|
      if fav_tag.user.is_privileged_or_higher?
        begin
          post_ids = Post.find_by_tags(fav_tag.tag_query, :limit => 60, :select => "p.id", :order => "p.id desc").map(&:id)
          fav_tag.add_posts!(post_ids)
          fav_tag.prune!
        rescue Exception => x
          # fail silently
        end
        sleep 1
      end
    end
  end
end
