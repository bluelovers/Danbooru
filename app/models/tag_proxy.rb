class TagProxy
  attr_reader :name
  
  def initialize(name, count = nil, tag_type = nil)
    @name = TagAlias.to_aliased_single(name)
    @count = count
    @tag_type = tag_type

    if @tag_type.nil? && @count.nil?
      @tag_type, @count = Tag.type_and_count(name)
    elsif @tag_type.nil?
      @tag_type, _ = Tag.type_and_count(name)
    elsif @count.nil?
      _, @count = Tag.type_and_count(name)
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
