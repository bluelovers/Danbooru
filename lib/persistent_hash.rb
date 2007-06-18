class PersistentHash
  def initialize(store, options = {})
    @hash = options[:hash] || {}
    @change_count = 0
    @commit_interval = options[:commit_interval] || 100
    @store = store
    
    case @store
    when :db
      @db_table_name = options[:table_name]
      @db_key_name = options[:key_name] || "name"
      @db_value_name = options[:value_name] || "value"
      @db_conn = options[:connection]
    end

    restore!
  end

  def method_missing(name, *args)
    @hash.send(name, *args)
  end

  def []=(key, value)
    @hash[key] = value
    @change_count += 1
    
    if @change_count >= @commit_interval
      @change_count = 0
      commit!
    end
  end

  def commit!
    case @store
    when :db
      @db_conn.execute("DELETE FROM #{@db_table_name}")
      
      @hash.each do |k, v|
        v = v.to_yaml.gsub(/'/, "''").gsub(/\\/, "\\\\")
        @db_conn.execute("INSERT INTO #{@db_table_name} (#{@db_key_name}, #{@db_value_name}) VALUES ('#{k}', '#{v}')")
      end
    end
  end

  private
  def restore!
    case @store
    when :db
      result = @db_conn.select_all("SELECT * FROM #{@db_table_name}")
      result.each do |x|
        @hash[x[@db_key_name]] = YAML.load(x[@db_value_name])
      end
    end
  end
end
