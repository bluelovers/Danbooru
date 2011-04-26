class BatchAliasAndImplicationCreator
  attr_accessor :text, :commands, :creator_id, :forum_id
  
  def initialize(text, creator_id, forum_id)
    @creator_id = creator_id
    @forum_id = forum_id
    @text = text
  end
  
  def process!
    tokens = lex(text)
    parse(tokens)
    create_job_tasks
  end
  
  def create_job_tasks
    TagImplication.find(:all, :conditions => "is_pending = true").each {|x| JobTask.create(:task_type => "approve_tag_implication", :status => "pending", :data => {"id" => x.id, "updater_id" => creator_id, "updater_ip_addr" => "127.0.0.1"})}
    TagAlias.find(:all, :conditions => "is_pending = true").each {|x| JobTask.create(:task_type => "approve_tag_alias", :status => "pending", :data => {"id" => x.id, "updater_id" => creator_id, "updater_ip_addr" => "127.0.0.1"})}
  end
  
  def lex(text)
    text.gsub!(/^\s+/, "")
    text.gsub!(/\s+$/, "")
    text.gsub!(/ {2,}/, " ")
    text.split(/\r\n|\r|\n/).map do |line|
      if line =~ /create alias (\S+) -> (\S+)/i
        [:create_alias, $1, $2]
      elsif line =~ /create implication (\S+) -> (\S+)/i
        [:create_implication, $1, $2]
      elsif line =~ /remove alias (\S+) -> (\S+)/i
        [:remove_alias, $1, $2]
      elsif line =~ /remove implication (\S+) -> (\S+)/i
        [:remove_implication, $1, $2]
      elsif line.empty?
        # do nothing
      else
        raise "Unparseable line: #{line}"
      end
    end
  end
  
  def parse(tokens)
    tokens.map do |token|
      case token[0]
      when :create_alias
        TagAlias.create(:creator_id => creator_id, :reason => "forum ##{forum_id}", :is_pending => true, :name => token[1], :alias => token[2])
        
      when :create_implication
        TagImplication.create(:creator_id => creator_id, :reason => "forum ##{forum_id}", :is_pending => true, :predicate => token[1], :consequent => token[2])
        
      when :remove_alias
        ta = TagAlias.find(:first, :conditions => ["name = ?", token[1]])
        raise "Alias for #{token[1]} not found" if ta.nil?
        ta.destroy
        
      when :remove_implication
        predicate = Tag.find_by_name(token[1])
        consequent = Tag.find_by_name(token[2])
        ti = TagImplication.find(:first, :conditions => ["predicate_id = ? and consequent_id = ?", predicate.id, consequent.id])
        raise "Implication for #{token[1]} not found" if ti.nil?
        ti.destroy
        
      else
        raise "Unknown token: #{token[0]}"
      end
    end
  end
end
