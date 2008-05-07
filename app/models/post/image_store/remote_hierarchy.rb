module PostImageStoreMethods
  module RemoteHierarchy
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
        select_random_image_server() + "/data/#{file_hierarchy}/#{file_name}"
      else
        CONFIG["url_base"] + "/data/#{file_hierarchy}/#{file_name}"
      end
    end

    def preview_path
      if status == "deleted"
        "#{RAILS_ROOT}/public/data/preview/deleted.png"
      elsif image?
        "#{RAILS_ROOT}/public/data/preview/#{file_hierarchy}/#{md5}.jpg"
      else
        "#{RAILS_ROOT}/public/data/preview/download.png"
      end
    end

    def sample_path
      "#{RAILS_ROOT}/public/data/sample/#{file_hierarchy}/" + CONFIG["sample_filename_prefix"] + "#{md5}.jpg"
    end

    def preview_url
      if self.is_warehoused?
        if status == "deleted"
          select_random_image_server() + "/data/preview/deleted.png"

        elsif image?
          select_random_image_server() + "/data/preview/#{file_hierarchy}/#{md5}.jpg"
        else
          select_random_image_server() + "/data/preview/download.png"
        end
      else
        if status == "deleted"
          CONFIG["url_base"] + "/data/preview/deleted.png"
        elsif image?
          CONFIG["url_base"] + "/data/preview/#{file_hierarchy}/#{md5}.jpg"
        else
          CONFIG["url_base"] + "/data/preview/download.png"
        end
      end
    end

    def store_sample_url
      if self.is_warehoused?
        select_random_image_server() + "/data/sample/#{file_hierarchy}/" + CONFIG["sample_filename_prefix"] + "#{md5}.jpg"
      else
        CONFIG["url_base"] + "/data/sample/#{file_hierarchy}/" + CONFIG["sample_filename_prefix"] + "#{md5}.jpg"
      end
    end

    def delete_file
      FileUtils.rm_f(file_path)
      FileUtils.rm_f(preview_path) if image?
      FileUtils.rm_f(sample_path) if image?
    end

    def move_file
      FileUtils.mkdir_p(File.dirname(file_path), :mode => 0775)
      FileUtils.mv(tempfile_path, file_path)
      FileUtils.chmod(0664, file_path)

      if image?
        FileUtils.mkdir_p(File.dirname(preview_path), :mode => 0775)
        FileUtils.mv(tempfile_preview_path, preview_path)
        FileUtils.chmod(0664, preview_path)
      end

      if File.exists?(tempfile_sample_path)
        FileUtils.mkdir_p(File.dirname(sample_path), :mode => 0775)
        FileUtils.mv(tempfile_sample_path, sample_path)
        FileUtils.chmod(0664, sample_path)
      end

      delete_tempfile
    end
  end
end
