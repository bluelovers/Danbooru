class Pool < ActiveRecord::Base
	class PostAlreadyExistsError < Exception
	end
	
	belongs_to :user
	validates_uniqueness_of :name
	before_save :normalize_name
	
	def normalize_name
		self.name = self.name.gsub(/\s/, "_")
	end
	
	def pretty_name
		self.name.gsub(/_/, " ")	
	end
	
	def add_post(post_id)
		if self.class.connection.select_value("SELECT 1 FROM pools_posts WHERE pool_id = #{self.id} AND post_id = #{post_id.to_i}")
			raise PostAlreadyExistsError
		end

		Pool.transaction do
			update_attributes(:updated_at => Time.now)
			self.class.connection.execute("INSERT INTO pools_posts (pool_id, post_id) VALUES (#{self.id}, #{post_id.to_i})")
		end
	end
	
	def remove_post(post_id)
		self.class.connection.execute("DELETE FROM pools_posts WHERE pool_id = #{self.id} AND post_id = #{post_id.to_i}")
	end
end

class PoolPost < ActiveRecord::Base
	set_table_name "pools_posts"
	belongs_to :post
	belongs_to :pool
end
