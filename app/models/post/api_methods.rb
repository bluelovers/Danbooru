module PostApiMethods
  def api_attributes
    return {
      :id => id, 
      :tags => cached_tags, 
      :created_at => created_at, 
      :creator_id => user_id, 
      :change => change_seq,
      :source => source, 
      :score => score, 
      :md5 => md5, 
      :file_url => file_url, 
      :preview_url => preview_url, 
      :preview_width => preview_dimensions[0],
      :preview_height => preview_dimensions[1],
      :sample_url => sample_url,
      :sample_width => sample_width || width,
      :sample_height => sample_height || height,
      :rating => rating, 
      :has_children => has_children, 
      :parent_id => parent_id, 
      :status => status,
      :width => width,
      :height => height
    }
  end

  def to_json(*args)
    return api_attributes.to_json(*args)
  end

  def to_xml(options = {})
    return api_attributes.to_xml(options.merge(:root => "post"))
  end
end
