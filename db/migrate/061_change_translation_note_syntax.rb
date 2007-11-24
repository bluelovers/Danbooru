class ChangeTranslationNoteSyntax < ActiveRecord::Migration
  def self.up
    execute "update notes set body = replace(body, '<tn>', '[tn]')"
    execute "update notes set body = replace(body, '</tn>', '[/tn]')"
    execute "update note_versions set body = replace(body, '<tn>', '[tn]')"
    execute "update note_versions set body = replace(body, '</tn>', '[/tn]')"
  end

  def self.down
    execute "update notes set body = replace(body, '[tn]', '<tn>')"
    execute "update notes set body = replace(body, '[/tn]', '</tn>')"
    execute "update note_versions set body = replace(body, '[tn]', '<tn>')"
    execute "update note_versions set body = replace(body, '[/tn]', '</tn>')"
  end
end
