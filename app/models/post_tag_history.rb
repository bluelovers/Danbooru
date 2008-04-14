class PostTagHistory < ActiveRecord::Base
  belongs_to :user

  class << self
    def generate_sql(options = {})
      Nagato::Builder.new do |builder, cond|
        cond.add_unless_blank "post_tag_histories.post_id = ?", options[:post_id]
        cond.add_unless_blank "post_tag_histories.user_id = ?", options[:user_id]
      
        if options[:user_name]
          builder.join "users ON users.id = post_tag_histories.user_id"
          cond.add "users.name = ?", options[:user_name]
        end
      end.to_hash
    end
  end

  # The contents of options[:posts] must be saved by the caller.  This allows
  # undoing many tag changes across many posts; all changes to a particular
  # post will be condensed into one change.
  def undo(options={})
    options[:posts] ||= {}
    options[:posts][self.post_id] ||= options[:post] = Post.find(self.post_id)
    post = options[:posts][self.post_id]
    post.tags = Post.find(self.post_id)

    current_tags = post.cached_tags.scan(/\S+/)

    prev = self.previous
    return if not prev

    changes = self.tag_changes(prev)

    new_tags = (current_tags - changes[:added_tags]) | changes[:removed_tags]

    options[:update_options] ||= {}
    post.attributes = {:tags => new_tags.join(" ")}.merge(options[:update_options])
  end

  def author
    return User.find_name(self.user_id)
  end

  def tag_changes(prev)
    new_tags = tags.scan(/\S+/)
    old_tags = (prev.tags rescue "").scan(/\S+/)
    latest = Post.find(self.post_id).cached_tags
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
    return PostTagHistory.find(:first, :order => "id DESC", :conditions => ["post_id = ? AND id < ?", post_id, id])
  end

  def to_xml(options = {})
    {:id => id, :post_id => post_id, :tags => tags}.to_xml(options.merge(:root => "tag_history"))
  end

  def to_json(*args)
    {:id => id, :post_id => post_id, :tags => tags}.to_json(*args)
  end
end
