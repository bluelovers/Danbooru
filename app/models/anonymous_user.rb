# This is a proxy class to make various nil checks unnecessary
class AnonymousUser
  def id
    nil
  end

  def level
    0
  end

  def comment_threshold
    0
  end
  
  def created_at
    Time.now
  end
  
  def updated_at
    Time.now
  end
  
  def name
    "Anonymous"
  end

  def pretty_name
    "Anonymous"
  end

  def is_anonymous?
    true
  end
  
  def has_mail?
    false
  end
  
  def has_forum_been_updated?
    false
  end

  def has_permission?(obj, foreign_key = :user_id)
    false
  end

  def ban
    false
  end
  
  def always_resize_images?
    false
  end
  
  def show_samples?
    true
  end

  def tag_subscriptions
    []
  end
  
  def upload_limit
    0
  end
  
  def base_upload_limit
    0
  end

  def uploaded_tags
    ""
  end
  
  def uploaded_tags_with_types
    []
  end
  
  def recent_tags
    ""
  end
  
  def recent_tags_with_types
    []
  end

  def can_upload?
    false
  end
  
  def can_comment?
    false
  end
  
  def can_remove_from_pools?
    false
  end
  
  CONFIG["user_levels"].each do |name, value|
    normalized_name = name.downcase.gsub(/ /, "_")

    define_method("is_#{normalized_name}?") do
      false
    end

    define_method("is_#{normalized_name}_or_higher?") do
      false
    end

    define_method("is_#{normalized_name}_or_lower?") do
      true
    end
  end
end
