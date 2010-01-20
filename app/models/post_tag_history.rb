class PostTagHistory < ActiveRecord::Base
  belongs_to :user
  belongs_to :post

  def self.generate_sql(options = {})
    Nagato::Builder.new do |builder, cond|
      cond.add_unless_blank "post_tag_histories.post_id = ?", options[:post_id]
      cond.add_unless_blank "post_tag_histories.user_id = ?", options[:user_id]
    
      if options[:user_name]
        builder.join "users ON users.id = post_tag_histories.user_id"
        cond.add "users.name = ?", options[:user_name]
      end
    end.to_hash
  end
  
  def self.undo_changes_by_user(user_id)
    transaction do  
      posts = Post.find(:all, :joins => "join post_tag_histories pth on pth.post_id = posts.id", :select => "distinct posts.*", :conditions => ["pth.user_id = ?", user_id])
            
      PostTagHistory.destroy_all(["user_id = ?", user_id])
      posts.each do |post|
        first = post.tag_history.first
        if first
          post.rating = first.rating
          post.tags = first.tags
          post.updater_ip_addr = first.ip_addr
          post.updater_user_id = first.user_id
          post.save!
        end
      end
    end
  end

  # The contents of options[:posts] must be saved by the caller.  This allows
  # undoing many tag changes across many posts; all changes to a particular
  # post will be condensed into one change.
  def undo(options={})
    # TODO: refactor. modifying parameters is a bad habit.
    options[:posts] ||= {}
    options[:posts][post_id] ||= options[:post] = Post.find(post_id)
    post = options[:posts][post_id]

    current_tags = post.cached_tags.scan(/\S+/)

    prev = previous
    return if not prev

    changes = tag_changes(prev)

    new_tags = (current_tags - changes[:added_tags]) | changes[:removed_tags]
    options[:update_options] ||= {}
    post.attributes = {:tags => new_tags.join(" "), :rating => prev.rating}.merge(options[:update_options])
  end

  def author
    User.find_name(user_id)
  end

  def tag_changes(prev)
    new_tags = tags.scan(/\S+/)
    old_tags = (prev.tags rescue "").scan(/\S+/)
    new_tags << "rating:#{rating}"
    new_tags << "parent:#{parent_id}"
    if prev
      old_tags << "rating:#{prev.rating}"
      old_tags << "parent:#{prev.parent_id}"
    end
    latest = Post.find(post_id).cached_tags
    latest_tags = latest.scan(/\S+/)

    {
      :added_tags => new_tags - old_tags,
      :removed_tags => old_tags - new_tags,
      :unchanged_tags => new_tags & old_tags,
      :obsolete_added_tags => new_tags - latest_tags,
      :obsolete_removed_tags => old_tags & latest_tags,
    }
  end

  def previous
    PostTagHistory.find(:first, :order => "id DESC", :conditions => ["post_id = ? AND id < ?", post_id, id])
  end

  def to_xml(options = {})
    {:id => id, :post_id => post_id, :tags => tags}.to_xml(options.merge(:root => "tag_history"))
  end

  def to_json(*args)
    {:id => id, :post_id => post_id, :tags => tags}.to_json(*args)
  end
end
