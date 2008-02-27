class ActiveRecord::Base
  class << self
    public :sanitize_sql
  end
end

class NilClass
  def id
    raise NoMethodError
  end

  # def to_json(options = {})
  #   "null"
  # end
end

class String
  # def to_json(options = {})
  #   return "\"" + to_escaped_js + "\""
  # end

  def to_escaped_for_sql_like
    # NOTE: gsub(/\\/, '\\\\') is a NOP, you need gsub(/\\/, '\\\\\\') if you want to turn \ into \\; or you can duplicate the matched text
    return self.gsub(/\\/, '\0\0').gsub(/%/, '\\%').gsub(/_/, '\\_').gsub(/\*/, '%')
  end

  def to_escaped_js
    return self.gsub(/\\/, '\0\0').gsub(/['"]/) {|m| "\\#{m}"}.gsub(/\r\n|\r|\n/, '\\n')
  end
end

class Symbol
  # def to_json(options = {})
  #   return "'" + to_s.to_escaped_js + "'"
  # end
end

class Integer
  # def to_json(options = {})
  #   return self
  # end
end

class TimeExtensions
  # def to_json(options = {})
  #   return "'" + to_s + "'"
  # end
end

class Array
  # def to_json(options = {})
  #   "[" + map {|x| x.to_json(options)}.join(",") + "]"
  # end
end

class FalseClass
  # def to_json(options = {})
  #   "false"
  # end
end

class TrueClass
  # def to_json(options = {})
  #   "true"
  # end
end

class Hash
  def included(m)
    m.alias_method :to_xml_orig, :to_xml
  end
  
  def to_xml(options = {})
    if false == options.delete(:no_children)
      to_xml_orig(options)
    else
      options[:indent] ||= 2
      options[:no_children] ||= true
      options[:root] ||= "hash"
      dasherize = !options.has_key?(:dasherize) || options[:dasherize]
      root = dasherize ? options[:root].dasherize : options[:root]
      options.reverse_merge!({:builder => Builder::XmlMarkup.new(:indent => options[:indent]), :root => root})
      options[:builder].instruct! unless options.delete(:skip_instruct)
      options[:builder].tag!(root, self)
    end
  end
  
  # def to_json(options = {})
  #   arr = []
  # 
  #   each do |k, v|
  #     arr << "#{k.to_json(options)}:#{v.to_json(options)}"
  #   end
  # 
  #   return "{" + arr.join(",") + "}"
  # end
end

