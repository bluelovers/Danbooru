class RelatedTagCalculator
  CONFIDENCE = 0.05

  def find_tags(tag, limit)
    Post.find_by_tags(tag, :limit => limit, :select => "p.cached_tags", :order => "p.md5").map(&:cached_tags)
  end

  def minimum_count(tags)
    counts = Tag.scan_tags(tags).map do |x|
      type, count = Tag.type_and_count(x)
      count
    end
  
    counts.min
  end
  
  def sample_size(population)
    size = population.to_f / (1 + (population.to_f * (CONFIDENCE * CONFIDENCE)))

    if size < 10
      size = 10
    else
      size.to_i
    end
  end
  
  def calculate_from_sample(name, limit = nil, category_constraint = nil)
    counts = Hash.new {|h, k| h[k] = 0}
    if limit == nil
      limit = sample_size(minimum_count(name))
      puts limit
    end
    
    case category_constraint
    when 1
      limit *= 5
      
    when 3
      limit *= 4
      
    when 4
      limit *= 3
    end
    
    find_tags(name, limit).each do |tags|
      tag_array = Tag.scan_tags(tags)
      if category_constraint
        tag_array.each do |tag|
          category = Tag.type_value(tag)
          if category == category_constraint
            counts[tag] += 1
          end
        end
      else
        tag_array.each do |tag|
          counts[tag] += 1
        end
      end
    end
    
    counts
  end
  
  def convert_hash_to_array(hash)
    hash.to_a.sort_by {|x| -x[1]}.slice(0, 25)
  end
  
  def convert_hash_to_string(hash)
    convert_hash_to_array(hash).flatten.join(" ")
  end
end
