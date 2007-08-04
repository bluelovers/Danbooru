module ImageStore
	def self.append_features(base) #:nodoc:
		super
		base.extend ClassMethods
	end

	module ClassMethods
		def image_store
			case CONFIG["image_store"]
			when :local_flat
				class_eval do
					include ImageStore::LocalFlat::InstanceMethods
				end

			when :local_hierarchy
				class_eval do
					include ImageStore::LocalHierarchy::InstanceMethods
				end

      when :remote_hierarchy
        class_eval do
          include ImageStore::RemoteHierarchy::InstanceMethods
        end

			when :amazon_s3
				class_eval do
					include ImageStore::AmazonS3::InstanceMethods
				end
			end
		end
	end

	module LocalFlat
		module InstanceMethods
			def file_path
				"#{RAILS_ROOT}/public/data/#{file_name}"
			end

			def file_url
				"http://" + CONFIG["server_host"] + "/data/#{file_name}"
			end

			def preview_path
				if image?
					"#{RAILS_ROOT}/public/data/preview/#{md5}.jpg"
				else
					"#{RAILS_ROOT}/public/data/preview/default.png"
				end
			end

			def preview_url
				if image?
					"http://" + CONFIG["server_host"] + "/data/preview/#{md5}.jpg"
				else
					"http://" + CONFIG["server_host"] + "/data/preview/default.png"
				end
			end

			def delete_file
				FileUtils.rm_f(file_path)
				FileUtils.rm_f(preview_path) if image?
			end

			def move_file
				FileUtils.mv(tempfile_path, file_path)
				FileUtils.chmod(0775, file_path)

				if image?
					puts tempfile_preview_path
					puts preview_path
					FileUtils.mv(tempfile_preview_path, preview_path)
					FileUtils.chmod(0775, preview_path)
				end

				delete_tempfile
			end
		end
	end

	module LocalHierarchy
		module InstanceMethods
			def file_hierarchy
				"%s/%s" % [md5[0,2], md5[2,2]]
			end

			def file_path
				"#{RAILS_ROOT}/public/data/#{file_hierarchy}/#{file_name}"
			end

			def file_url
				"http://" + CONFIG["server_host"] + "/data/#{file_hierarchy}/#{file_name}"
			end

			def preview_path
				if image?
					"#{RAILS_ROOT}/public/data/preview/#{file_hierarchy}/#{md5}.jpg"
				else
					"#{RAILS_ROOT}/public/data/preview/default.png"
				end
			end

			def preview_url
				if image?
					"http://" + CONFIG["server_host"] + "/data/preview/#{file_hierarchy}/#{md5}.jpg"
				else
					"http://" + CONFIG["server_host"] + "/data/preview/default.png"
				end
			end

			def delete_file
				FileUtils.rm_f(file_path)
				FileUtils.rm_f(preview_path) if image?
			end

			def move_file
				FileUtils.mkdir_p(File.dirname(file_path), :mode => 0775)
				FileUtils.mv(tempfile_path, file_path)
				FileUtils.chmod(0775, file_path)

				if image?
					FileUtils.mkdir_p(File.dirname(preview_path), :mode => 0775)
					FileUtils.mv(tempfile_preview_path, preview_path)
					FileUtils.chmod(0775, preview_path)
				end

				delete_tempfile
			end
		end
	end

  module RemoteHierarchy
    module InstanceMethods
			def file_hierarchy
				"%s/%s" % [md5[0,2], md5[2,2]]
			end
      
      def select_random_image_server
        CONFIG["image_servers"][rand(CONFIG["image_servers"].size)]
      end

			def file_path
				"#{RAILS_ROOT}/public/data/#{file_hierarchy}/#{file_name}"
			end

			def file_url
        if self.is_warehoused?
          select_random_image_servers() + "/data/#{file_hierarchy}/#{file_name}"
        else
          "http://" + CONFIG["server_host"] + "/data/#{file_hierarchy}/#{file_name}"
        end
      end

			def preview_path
        if image?
          "#{RAILS_ROOT}/public/data/preview/#{file_hierarchy}/#{md5}.jpg"
        else
          "#{RAILS_ROOT}/public/data/preview/default.png"
        end
			end

			def preview_url
        if self.is_warehoused?
          if image?
            select_random_image_server() + "/data/preview/#{file_hierarchy}/#{md5}.jpg"
          else
            select_random_image_server() + "/data/preview/default.png"
          end
        else
          if image?
            "http://" + CONFIG["server_host"] + "/data/preview/#{file_hierarchy}/#{md5}.jpg"
          else
            "http://" + CONFIG["server_host"] + "/data/preview/default.png"
          end
        end
			end

			def delete_file
				FileUtils.rm_f(file_path)
				FileUtils.rm_f(preview_path) if image?
			end

			def move_file
				FileUtils.mkdir_p(File.dirname(file_path), :mode => 0775)
				FileUtils.mv(tempfile_path, file_path)
				FileUtils.chmod(0775, file_path)

				if image?
					FileUtils.mkdir_p(File.dirname(preview_path), :mode => 0775)
					FileUtils.mv(tempfile_preview_path, preview_path)
					FileUtils.chmod(0775, preview_path)
				end

				delete_tempfile
			end
    end
  end

	module AmazonS3
		module InstanceMethods
			def move_file
				begin
					Timeout::timeout(30) do
						AWS::S3::Base.establish_connection!(:access_key_id => CONFIG["amazon_s3_access_key_id"], :secret_access_key => CONFIG["amazon_s3_secret_access_key"])
						AWS::S3::S3Object.store(file_name, open(self.tempfile_path, "rb"), CONFIG["amazon_s3_bucket_name"], :access => :public_read)
						if image?
							AWS::S3::S3Object.store("preview/#{md5}.jpg", open(self.tempfile_preview_path, "rb"), CONFIG["amazon_s3_bucket_name"], :access => :public_read)
						end
						delete_tempfile
					end
					return true
				rescue Exception => e
					self.errors.add('source', e.to_s)
					delete_tempfile
					return false
				end
			end

			def file_url
				"http://s3.amazonaws.com/" + CONFIG["amazon_s3_bucket_name"] + "/#{file_name}"
			end

			def preview_url
				if self.image?
					"http://s3.amazonaws.com/" + CONFIG["amazon_s3_bucket_name"] + "/preview/#{md5}.jpg"
				else
					"http://s3.amazonaws.com/" + CONFIG["amazon_s3_bucket_name"] + "/preview/default.png"
				end
			end

			def delete_file
				AWS::S3::Base.establish_connection!(:access_key_id => CONFIG["amazon_s3_access_key_id"], :secret_access_key => CONFIG["amazon_s3_secret_access_key"])
				AWS::S3::S3Object.delete(file_name, CONFIG["amazon_s3_bucket_name"])
				AWS::S3::S3Object.delete("preview/#{md5}.jpg", CONFIG["amazon_s3_bucket_name"])
			end
		end
	end
end

ActiveRecord::Base.class_eval do
	include ImageStore
end
