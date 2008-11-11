desc 'Revert some tag alias changes'
task :revert_aliases => :environment do
  TagAlias.transaction do
    TagAlias.find(:all, :conditions => "(id between 2663 and 2821 or id between 2829 and 2858 or id = 2861 or id = 2872 or id = 2873) and creator_id = 65656").each do |ta|
      a = ta.name
      b = ta.alias_name
      ta.destroy
      Tag.mass_edit(b, a, 1, "127.0.0.1")
    end
  end
end
