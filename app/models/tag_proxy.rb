class TagProxy
  attr_reader :name
  
  def initialize(name, count = nil, tag_type = nil)
    @name = TagAlias.to_aliased_single(name)
    @count = count
    @tag_type = tag_type

    if @tag_type.nil? && @count.nil?
      tag = Tag.find(:first, :conditions => ["name = ?", @name], :select => "id, tag_type, post_count")
      if tag
        @count = tag.post_count
        @tag_type = Tag.type_name_from_value(tag.tag_type)
      else
        @count = 0
        @tag_type = "General"
      end
    elsif @count.nil?
      tag = Tag.find(:first, :conditions => ["name = ?", @name], :select => "id, post_count")
      if tag
        @count = tag.post_count
      else
        @count = 0
      end
    elsif @tag_type.nil?
      tag = Tag.find(:first, :conditions => ["name = ?", @name], :select => "id, tag_type")
      if tag
        @tag_type = Tag.type_name_from_value(tag.tag_type)
      else
        @tag_type = "General"
      end
    end
  end
  
  def tag_type
    @tag_type
  end
  
  def post_count
    @count
  end
  
  def to_s
    @name
  end
  
  def strip!(regexp)
    @name.sub!(regexp, '')
  end
end
