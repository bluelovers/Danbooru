class WikiPage < ActiveRecord::Base
  acts_as_versioned :table_name => "wiki_page_versions", :foreign_key => "wiki_page_id", :order => "updated_at DESC"
  before_save :make_title_canonical
  belongs_to :user
  validates_uniqueness_of :title, :case_sensitive => false
  validates_presence_of :body
  
  TAG_DEL = '<del>'
  TAG_INS = '<ins>'
  TAG_DEL_CLOSE = '</del>'
  TAG_INS_CLOSE = '</ins>'
  TAG_NEWLINE = "<img src=\"/images/nl.png\" alt=\"newline\">\n"
  TAG_BREAK = "<br>\n"
  
  class << self
    def generate_sql(options)
      joins = []
      conds = []
      params = []
      
      if options[:title]
        conds << "wiki_pages.title = ?"
        params << options[:title]
      end
      
      if options[:user_id]
        conds << "wiki_pages.user_id = ?"
        params << options[:user_id]
      end
      
      joins = joins.join(" ")
      conds = [conds.join(" AND "), *params]
      
      return joins, conds
    end
  end
  
  def make_title_canonical
    self.title = title.tr(" ", "_").downcase
  end

  def last_version?
    self.version == self.next_version.to_i - 1
  end

  def first_version?
    self.version == 1
  end

  def author
    return User.find_name(self.user_id)
  end

  def pretty_title
    self.title.tr("_", " ")
  end
  
# Produce a formatted page that shows the difference between two versions of a page.
  def diff(version)
    otherpage = WikiPage.find_page(title, version)

    pattern = Regexp.new('(?:<.+?>)|(?:[0-9_A-Za-z\x80-\xff]+[\x09\x20]?)|(?:[ \t]+)|(?:\r?\n)|(?:.+?)')

    thisarr = self.body.scan(pattern)
    otharr = otherpage.body.scan(pattern)

    cbo = Diff::LCS::ContextDiffCallbacks.new
    diffs = thisarr.diff(otharr, cbo)

    escape_html = lambda {|str| str.gsub(/&/,'&amp;').gsub(/</,'&lt;').gsub(/>/,'&gt;')}

    output = thisarr;
    output.each { |q| q.replace(escape_html[q]) }

    diffs.reverse_each do |hunk|
      newchange = hunk.max{|a,b| a.old_position <=> b.old_position}
      newstart = newchange.old_position
      oldstart = hunk.min{|a,b| a.old_position <=> b.old_position}.old_position

      if newchange.action == '+'
        output.insert(newstart, TAG_INS_CLOSE)
      end

      hunk.reverse_each do |chg|
        case chg.action
        when '-'
          oldstart = chg.old_position
          output[chg.old_position] = TAG_NEWLINE if chg.old_element.match(/^\r?\n$/)
        when '+'
          if chg.new_element.match(/^\r?\n$/)
            output.insert(chg.old_position, TAG_NEWLINE)
          else
            output.insert(chg.old_position, "#{escape_html[chg.new_element]}")
          end
        end
      end

      if newchange.action == '+'
        output.insert(newstart, TAG_INS)
      end

      if hunk[0].action == '-'
        output.insert((newstart == oldstart || newchange.action != '+') ? newstart+1 : newstart, TAG_DEL_CLOSE)
        output.insert(oldstart, TAG_DEL)
      end
    end

    output.join.gsub(/\r?\n/, TAG_BREAK)
  end

# Finds a page. This method automatically sanitizes the title, and can also supply previous versions.
  def self.find_page(title, version = nil)
    return nil if title.blank?

    page = find_by_title(title)
    page.revert_to(version) if version && page

    return page
  end
  
  def self.find_by_title(title)
    return find(:first, :conditions => ["lower(title) = lower(?)", title.tr(" ", "_")])
  end
  
  def lock!
    connection.execute("UPDATE wiki_pages SET is_locked = TRUE WHERE id = #{id}")
    connection.execute("UPDATE wiki_page_versions SET is_locked = TRUE WHERE wiki_page_id = #{id}")
  end

  def unlock!
    connection.execute("UPDATE wiki_pages SET is_locked = FALSE WHERE id = #{id}")
    connection.execute("UPDATE wiki_page_versions SET is_locked = FALSE WHERE wiki_page_id = #{id}")
  end

  def rename!(new_title)
    connection.execute(WikiPage.sanitize_sql(["UPDATE wiki_pages SET title = ? WHERE id = ?", new_title, self.id]))
    connection.execute(WikiPage.sanitize_sql(["UPDATE wiki_page_versions SET title = ? WHERE wiki_page_id = ?", new_title, self.id]))
  end

  def to_xml(options = {})
    {:id => id, :created_at => created_at, :updated_at => updated_at, :title => title, :body => body, :updater_id => user_id, :locked => is_locked, :version => version}.to_xml(options.merge(:root => "wiki_page"))
  end

  def to_json(options = {})
    {:id => id, :created_at => created_at, :updated_at => updated_at, :title => title, :body => body, :updater_id => user_id, :locked => is_locked, :version => version}.to_json(options)
  end
end
