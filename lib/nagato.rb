# Nagato is a library that allows you to programatically build SQL queries.
module Nagato
  # Represents a single subquery.
  class Subquery
    # === Parameters
    # * :join<String>:: Can be either "and" or "or". All the conditions will be joined using this string.
    def initialize(join = "and")
      @join = join.upcase
      @conditions = ["TRUE"]
      @condition_params = []
    end

    def conditions
      [@conditions.join(" " + @join + " "), *@condition_params]
    end
    
    # Creates a subquery (within the curreny subquery).
    #
    # === Parameters
    # * :join<String>:: Can be either "and" or "or". This will be passed on to the generated subquery.
    def subquery(join = "and")
      subconditions = self.class.new(join)
      yield(subconditions)
      c = subconditions.conditions
      @conditions << "(#{c[0]})"
      @condition_params += c[1..-1]
    end
    
    # Adds a condition to the subquery. If the condition has placeholder parameters, you can pass them in directly in :params:.
    #
    # === Parameters
    # * :sql<String>:: A SQL fragment.
    # * :params<Object>:: A list of object to be used as the placeholder parameters.
    def add(sql, *params)
      @conditions << sql
      @condition_params += params
    end
  end
  
  class MissingBaseTable < Exception
  end
  
  class Builder
    attr_reader :order, :limit, :offset
    
    def initialize(table = nil)
      @build_full_sql = (table.nil? ? false : true)
      
      @select = []
      @from = [table]
      @joins = []
      @join_params = []
      @conditions = ["TRUE"]
      @condition_params = []
      @order = nil
      @offset = nil
      @limit = nil
      
      if block_given?
        yield(self)
      end
    end
    
    def self.conditions(join = "and", &block)
      b = self.new
      b.where(join, &block)
      return b.to_a
    end
    
    def join(sql, *params)
      raise MissingBaseTable unless @build_full_sql
      
      @joins << "JOIN " + sql
      @join_params += params
    end
    
    def ljoin(sql, *params)
      raise MissingBaseTable unless @build_full_sql
      
      @joins << "LEFT JOIN " + sql
      @join_params += params
    end

    def rjoin(sql, *params)
      raise MissingBaseTable unless @build_full_sql
      
      @joins << "RIGHT JOIN " + sql
      @join_params += params
    end

    # === Parameters
    # * :fields<String, Array>: the fields to select
    def get(fields)
      if fields.is_a?(String)
        @select << fields
      elsif fields.is_a?(Array)
        @select += fields
      else
        raise TypeError
      end
    end

    # === Parameters
    # * :tables<String, Array>: tables to select from
    def from(tables)
      if tables.is_a?(String)
        @from << tables
      elsif tables.is_a?(Array)
        @from += tables
      else
        raise TypeError
      end
    end
    
    def where(join = "and")
      sub = Subquery.new(join)
      yield(sub)
      c = sub.conditions
      @conditions << "(#{c[0]})"
      @condition_params += c[1..-1]
    end
    
    def order(sql)
      @order = sql
    end
    
    def limit(amount)
      @limit = amount
    end
    
    def offset(amount)
      @offset = amount
    end
    
    def joins
      return [@joins.join(" "), *@join_params]
    end
    
    def conditions
      return [@conditions.join(" AND "), *@condition_params]
    end

    def to_hash
      hash = {}
      hash[:conditions] = conditions if @conditions.any?
      hash[:joins] = joins if @joins.any?
      hash[:order] = @order if @order
      hash[:limit] = @limit if @limit
      hash[:offset] = @offset if @offset
      return hash
    end
    
    def to_a
      if @conditions.empty?
        conditions = ["TRUE"]
      else
        conditions = @conditions
      end

      if @from.nil?
        [conditions.join(" AND "), *@condition_params]
      else
        if @select.empty?
          select = ["*"]
        else
          select = @select
        end
      
        sql = ["SELECT"]
        sql << select.join(", ")
        sql << "FROM"
        sql << @from.join(", ")
        sql << @joins.join(" ")
        sql << "WHERE"
        sql << conditions.join(" AND ")
        sql << @order
        sql << @offset
        sql << @limit
        
        [sql.compact.join(" "), @join_params + @condition_params]
      end
    end
  end
end

# Nagato::Builder.new("posts") do |b|
#   b.get("posts.id")
#   b.get("posts.rating")
#   b.rjoin("posts_tags ON posts_tags.post_id = posts.id")
#   b.where("or") do |c1|
#     c1.add "posts.rating = 's'"
#     c1.subquery do |c2|
#       c2.add "posts.user_id is null"
#       c2.add "posts.user_id = 1"
#     end
#   end
#   b.where do |c1|
#     c1.add "posts.status <> 'deleted'"
#   end
#   puts b.to_a
# end
