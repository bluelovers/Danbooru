module TagReportMethods
  module ClassMethods
    def report_daily_count(query)
      sql = Post.generate_sql(query)
      sql.sub!("p.*", "EXTRACT(YEAR FROM p.created_at)::text || LPAD(EXTRACT(DOY FROM p.created_at)::text, 3, '0') AS post_date, COUNT(*) AS post_count")
      sql.sub!("ORDER BY p.id DESC", "GROUP BY post_date ORDER BY post_date")
      results = connection.select_all(sql).inject({}) {|h, x| h[x["post_date"]] = x["post_count"]; h}
      puts results.keys.inspect
      min_date = results.keys.min
      max_date = results.keys.max
      
      if min_date
        (min_date..max_date).each do |date|
          date =~ /(\d{4})(\d{3})/
        
          year = $1.to_i
          doy = $2.to_i
        
          next if doy > 365
        
          if !results.has_key?("#{year}#{day}")
            results["#{year}#{day}"] = 0
          end
        end
      end
      
      results
    end
  end
  
  def self.included(m)
    m.extend(ClassMethods)
  end
end
