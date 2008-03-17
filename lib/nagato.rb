# Nagato is a library that allows you to programatically build SQL queries.
module Nagato
  # Represents a single subquery.
  class Subquery
    # === Parameters
    # * :join<String>:: Can be either "and" or "or". All the conditions will be joined using this string.
    def initialize(join = "and")
      @join = join.upcase
      @conditions = []
      @condition_params = []
    end

    # Returns true if the subquery is empty.
    def empty?
      return @conditions.empty?
    end

    # Returns an array of 1 or more elements, the first being a SQL fragment and the rest being placeholder parameters.
    def conditions
      if @conditions.empty?
        return ["TRUE"]
      else
        return [@conditions.join(" " + @join + " "), *@condition_params]
      end
    end
    
    # Creates a subquery (within the current subquery).
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
    
    # A special case in which there's only one parameter. If the parameter is nil, then don't add the condition.
    #
    # === Parameters
    # * :sql<String>:: A SQL fragment.
    # * :param<Object>:: A placeholder parameter.
    def add_unless_blank(sql, param)
      if param != nil
        @conditions << sql
        @condition_params << param
      end
    end
  end
  
  class Builder
    attr_reader :order, :limit, :offset
    
    def initialize(table = nil)
      @select = []
      @from = []
      @joins = []
      @join_params = []
      @subquery = Subquery.new("and")
      @order = nil
      @offset = nil
      @limit = nil

      @from << table unless table.nil?
      
      if block_given?
        yield(self, @subquery)
      end
    end

    def join(sql, *params)
      @joins << "JOIN " + sql
      @join_params += params
    end
    
    def ljoin(sql, *params)
      @joins << "LEFT JOIN " + sql
      @join_params += params
    end

    def rjoin(sql, *params)
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
    
    def order(sql)
      @order = sql
    end
    
    def limit(amount)
      @limit = amount.to_i
    end
    
    def offset(amount)
      @offset = amount.to_i
    end
    
    def conditions
      return @subquery.conditions
    end

    def joins
      return [@joins.join(" "), *@join_params]
    end
    
    def to_hash
      hash = {}
      hash[:conditions] = conditions
      hash[:joins] = joins if @joins.any?
      hash[:order] = @order if @order
      hash[:limit] = @limit if @limit
      hash[:offset] = @offset if @offset
      return hash
    end
  end
end

# Nagato::Builder.new("posts") do |builder, cond|
#   builder.get("posts.id")
#   builder.get("posts.rating")
#   builder.rjoin("posts_tags ON posts_tags.post_id = posts.id")
#   cond.add_unless_blank "posts.rating = ?", params[:rating]
#   cond.subquery do |c1|
#     c1.add "posts.user_id is null"
#     c1.add "posts.user_id = 1"
#   end
#
#   puts b.to_hash
# end
