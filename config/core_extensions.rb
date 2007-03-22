# Why the hell is sanitize_sql protected, I don't know.
class ActiveRecord::Base
	class << self
		public :sanitize_sql
	end
end

class NilClass
	def id
		raise NoMethodError
	end
end

class String
	def to_json(options = {})
		return "'%s'" % self
	end
end

class Symbol
	def to_json(options = {})
		return to_s
	end
end

class Integer
	def to_json(options = {})
		return self
	end
end

class Array
	def to_json(options = {})
		"[" + map {|x| x.to_json(options)}.join(",") + "]"
	end
end

class Hash
	def to_json(options = {})
		arr = []

		each do |k, v|
			arr << "#{k.to_json(options)}:#{v.to_json(options)}"
		end

		return "{" + arr.join(",") + "}"
	end
end
