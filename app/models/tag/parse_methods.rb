module TagParseMethods
  module ClassMethods
    def scan_query(query)
      query.to_s.downcase.scan(/\S+/).uniq
    end

    def scan_tags(tags)
      tags.to_s.gsub(/[%,]/, "").downcase.scan(/\S+/).uniq
    end
    
    def parse_cast(x, type)
      if type == :integer
        x.to_i
      elsif type == :float
        x.to_f
      elsif type == :date
        begin
          x.to_date
        rescue Exception
          nil
        end
      elsif type == :filesize
        x =~ /^(\d+(?:\.\d*)?|\d*\.\d+)([kKmM]?)[bB]?$/

	size = $1.to_f
	unit = $2

	conversion_factor = case unit
	  when /m/i
	    1024 * 1024
	  when /k/i
	    1024
	  else
	    1
	end

	(size * conversion_factor).to_i
      end
    end
    
    def parse_helper(range, type = :integer)
      # "1", "0.5", "5.", ".5":
      # (-?(\d+(\.\d*)?|\d*\.\d+))
      case range
      when /^(.+?)\.\.(.+)/
        return [:between, parse_cast($1, type), parse_cast($2, type)]

      when /^<=(.+)/, /^\.\.(.+)/
        return [:lte, parse_cast($1, type)]

      when /^<(.+)/
        return [:lt, parse_cast($1, type)]

      when /^>=(.+)/, /^(.+)\.\.$/
        return [:gte, parse_cast($1, type)]

      when /^>(.+)/
        return [:gt, parse_cast($1, type)]

      else
        return [:eq, parse_cast(range, type)]

      end
    end

  # Parses a query into three sets of tags: reject, union, and intersect.
  #
  # === Parameters
  # * +query+: String, array, or nil. The query to parse.
  # * +options+: A hash of options.
    def parse_query(query, options = {})
      q = Hash.new {|h, k| h[k] = []}

      scan_query(query).each do |token|
        if token =~ /^(unlocked|user|sub|fav|md5|-rating|rating|width|height|mpixels|score|filesize|source|id|date|pool|parent|order|change|status|generaltagcount|artisttagcount|charactertagcount|copyrighttagcount):(.+)$/
          if $1 == "user"
            q[:user] = $2
          elsif $1 == "fav"
            q[:fav] = $2
          elsif $1 == "sub"
            q[:subscriptions] = $2
          elsif $1 == "md5"
            q[:md5] = $2
          elsif $1 == "-rating"
            q[:rating_negated] = $2
          elsif $1 == "rating"
            q[:rating] = $2
          elsif $1 == "id"
            q[:post_id] = parse_helper($2)
          elsif $1 == "width"
            q[:width] = parse_helper($2)
          elsif $1 == "height"
            q[:height] = parse_helper($2)
          elsif $1 == "mpixels"
            q[:mpixels] = parse_helper($2, :float)
          elsif $1 == "score"
            q[:score] = parse_helper($2)
	  elsif $1 == "filesize"
	    q[:filesize] = parse_helper($2, :filesize)
          elsif $1 == "source"
            q[:source] = $2.to_escaped_for_sql_like + "%"
          elsif $1 == "date"
            q[:date] = parse_helper($2, :date)
          elsif $1 == "generaltagcount"
            q[:general_tag_count] = parse_helper($2)
          elsif $1 == "artisttagcount"
            q[:artist_tag_count] = parse_helper($2)
          elsif $1 == "charactertagcount"
            q[:character_tag_count] = parse_helper($2)
          elsif $1 == "copyrighttagcount"
            q[:copyright_tag_count] = parse_helper($2)
          elsif $1 == "pool"
            q[:pool] = $2
            if q[:pool] =~ /^(\d+)$/
              q[:pool] = q[:pool].to_i
            end
          elsif $1 == "parent"
            if $2 == "none"
              q[:parent_id] = false
            else
              q[:parent_id] = $2.to_i
            end
          elsif $1 == "order"
            q[:order] = $2
          elsif $1 == "unlocked"
            if $2 == "rating"
              q[:unlocked_rating] = true
            end
          elsif $1 == "change"
            q[:change] = parse_helper($2)
          elsif $1 == "status"
            q[:status] = $2
          elsif $1 == "voteup"
            q[:voteup] = $2
          elsif $1 == "votedown"
            q[:votedown] = $2
          end
        elsif token[0] == ?- && token.size > 1
          q[:exclude] << token[1..-1]
        elsif token[0] == ?~ && token.size > 1
          q[:include] << token[1..-1]
        elsif token.include?("*")
          matches = find(:all, :conditions => ["name LIKE ? ESCAPE E'\\\\'", token.to_escaped_for_sql_like], :select => "name", :limit => 25, :order => "post_count DESC").map(&:name)
          matches = ["~no_matches~"] if matches.empty?
          q[:include] += matches
        else
          q[:related] << token
        end
      end

      q[:exclude] = TagAlias.to_aliased(q[:exclude], :strip_prefix => true) if q.has_key?(:exclude)
      q[:include] = TagAlias.to_aliased(q[:include], :strip_prefix => true) if q.has_key?(:include)
      q[:related] = TagAlias.to_aliased(q[:related]) if q.has_key?(:related)

      return q
    end
  end

  def self.included(m)
    m.extend(ClassMethods)
  end
end
