require 'rbconfig'

module Arch
	def self.windows?
		if Config::CONFIG['arch'] =~ /(win)|(mingw)/
			true
		else
			false
		end
	end

	def self.linux?
		if Config::CONFIG['arch'] =~ /linux/
			true
		else
			false
		end
	end

	def self.interpreter_path
		@@interpreter_path ||= File.join(Config::CONFIG['bindir'], "#{Config::CONFIG['ruby_install_name']}#{Config::CONFIG['EXEEXT']}")
	end

	def self.rm_rf(file)
		if linux?
			`rm -rf #{file}`
		else
			FileUtils.rm_rf(file)
		end
	end
end

