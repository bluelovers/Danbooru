module TagRelatedTagMethods
  module ClassMethods
    def cache_duration(count)
      duration = count / 3
      duration = 12 if duration < 12
      duration = 200 if duration > 200
      duration.hours.to_i
    end
    
    def calculate_related_by_type(tag, type, limit = 25)
      duration = cache_duration(Tag.find_or_create_by_name(tag).post_count)
      
      json = Cache.get(Digest::MD5.hexdigest("reltagsbytype/#{type}/#{tag}"), duration) do
        begin
          results = select_all_sql("SELECT (SELECT name FROM tags WHERE id = pt0.tag_id) AS name, COUNT(pt0.tag_id) AS post_count FROM posts_tags pt0, posts_tags pt1 WHERE pt0.post_id = pt1.post_id AND pt1.tag_id = (SELECT id FROM tags WHERE name = ?) AND pt0.tag_id IN (SELECT id FROM tags WHERE tag_type = ?) GROUP BY pt0.tag_id ORDER BY post_count DESC LIMIT ?", tag, type, limit)
        rescue Exception
          results = []
        end

        results.map do |x|
          {"name" => x["name"], "post_count" => x["post_count"]}
        end.to_json
      end
      
      JSON.parse(json)
    end

    def calculate_related(tags)
      tags = Array(tags)
      return [] if tags.empty?

      from = ["posts_tags pt0"]
      cond = ["pt0.post_id = pt1.post_id"]
      sql = ""

      # Ignore deleted posts in pt0, so the count excludes them.
      cond << "(SELECT TRUE FROM POSTS p0 WHERE p0.id = pt0.post_id AND p0.status <> 'deleted')"

      (1..tags.size).each {|i| from << "posts_tags pt#{i}"}
      (2..tags.size).each {|i| cond << "pt1.post_id = pt#{i}.post_id"}
      (1..tags.size).each {|i| cond << "pt#{i}.tag_id = (SELECT id FROM tags WHERE name = ?)"}

      sql << "SELECT (SELECT name FROM tags WHERE id = pt0.tag_id) AS tag, COUNT(pt0.*) AS tag_count"
      sql << " FROM " << from.join(", ")
      sql << " WHERE " << cond.join(" AND ")
      sql << " GROUP BY pt0.tag_id"
      sql << " ORDER BY tag_count DESC LIMIT 25"

      begin
        select_all_sql(sql, *tags).map {|x| [x["tag"], x["tag_count"]]}
      rescue Exception
        []
      end
    end

    def find_related(tags)
      if tags.is_a?(Array) && tags.size > 1
        return calculate_related(tags)
      else
        t = find_by_name(tags.to_s)
        if t
          return t.related
        else
          return []
        end
      end
    end
  end
  
  def self.included(m)
    m.extend(ClassMethods)
  end
  
  def commit_related(related_tags)
    duration = Tag.cache_duration(post_count)
    execute_sql("UPDATE tags SET cached_related = ?, cached_related_expires_on = ? WHERE id = ?", related_tags.flatten.join(","), duration.from_now, id)
    reload
  end
  
  def related(force_immediate_recalculation = false)
    if Time.now > cached_related_expires_on
      if force_immediate_recalculation || post_count < 100
        commit_related(Tag.calculate_related(name))
      elsif !JobTask.exists?(["task_type = 'calculate_related_tags' AND data_as_json = '{\"id\":#{id}}'"])
        JobTask.create(:task_type => "calculate_related_tags", :status => "pending", :data => {"id" => id})
      end
    end

    return cached_related.split(/,/).in_groups_of(2)
  end
end

