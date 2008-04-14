module TagMethods
  module RelatedTagMethods
    module ClassMethods
      def calculate_related_by_type(tag, type, limit = 25)
        sql = <<-EOS
          SELECT (SELECT name FROM tags WHERE id = pt0.tag_id) AS name,
          COUNT(pt0.tag_id) AS post_count
          FROM posts_tags pt0, posts_tags pt1
          WHERE pt0.post_id = pt1.post_id
          AND pt1.tag_id = (SELECT id FROM tags WHERE name = ?)
          AND pt0.tag_id IN (SELECT id FROM tags WHERE tag_type = ?)
          GROUP BY pt0.tag_id
          ORDER BY post_count DESC
          LIMIT ?
        EOS

        return select_all_sql(sql, tag, type, limit)
      end

      def calculate_related(tags)
        tags = Array(tags)
        return [] if tags.empty?

        from = ["posts_tags pt0"]
        cond = ["pt0.post_id = pt1.post_id"]
        sql = ""

        (1..tags.size).each {|i| from << "posts_tags pt#{i}"}
        (2..tags.size).each {|i| cond << "pt1.post_id = pt#{i}.post_id"}
        (1..tags.size).each {|i| cond << "pt#{i}.tag_id = (SELECT id FROM tags WHERE name = ?)"}

        sql << "SELECT (SELECT name FROM tags WHERE id = pt0.tag_id) AS tag, COUNT(pt0.*) AS tag_count"
        sql << " FROM " << from.join(", ")
        sql << " WHERE " << cond.join(" AND ")
        sql << " GROUP BY pt0.tag_id"
        sql << " ORDER BY tag_count DESC LIMIT 25"

        return select_all_sql(sql, *tags).map {|x| [x["tag"], x["tag_count"]]}
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

    def related
      if Time.now > cached_related_expires_on
        length = post_count / 3
        length = 12 if length < 12
        length = 8760 if length > 8760

        execute_sql("UPDATE tags SET cached_related = ?, cached_related_expires_on = ? WHERE id = ?", self.class.calculate_related(name).flatten.join(","), length.hours.from_now, id)
        reload
      end

      return self.cached_related.split(/,/).in_groups_of(2)
    end
  end
end
