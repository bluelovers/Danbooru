class TagProxy
  attr_reader :name
  
  def initialize(name, count = nil, tag_type = nil)
    @name = TagAlias.to_aliased_single(name)
    @count = count
    @tag_type = tag_type
  end
  
  def tag_type
    if @tag_type.nil?
      @tag_type = Tag.type_name(@name)
    end
    
    @tag_type
  end
  
  def post_count
    if @count.nil?
      @count = Cache.get("post_count:#{@name}", 4.hours) do
        tag = Tag.find(:first, :conditions => ["name = ?", @name], :select => "id, post_count")
      
        if tag
          tag.post_count
        else
          0
        end
      end
    end
    
    return @count
  end
  
  def to_s
    @name
  end
  
  def strip!(regexp)
    @name.sub!(regexp, '')
  end
end
