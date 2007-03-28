class Artist < ActiveRecord::Base
	before_save :normalize

	def normalize
		self.personal_name = self.personal_name.downcase.gsub(/ /, '_') if self.personal_name
		self.handle_name = self.handle_name.downcase.gsub(/ /, '_') if self.handle_name
		self.site_name = self.site_name.downcase.gsub(/ /, '_') if self.site_name

		self.site_url.gsub!(/\/$/, "") if self.site_url
		self.image_url.gsub!(/\/$/, "") if self.image_url
	end

	def name
		if !self.personal_name.blank?
			self.personal_name
		elsif !self.handle_name.blank?
			self.handle_name
		elsif !self.circle_name.blank?
			self.circle_name
		else
			nil
		end
	end

	def to_json(options = {})
		{:id => self.id, :personal_name => self.personal_name, :circle_name => self.circle_name, :handle_name => self.handle_name, :site_url => self.site_url, :image_url => self.image_url}.to_json(options)
	end

	def self.find_by_name(name)
		return find(:first, :conditions => ["japanese_name = ? OR personal_name = ? OR handle_name = ? OR circle_name = ?", name, name, name, name])
	end
end
