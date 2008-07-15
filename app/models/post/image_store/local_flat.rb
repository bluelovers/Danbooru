module PostImageStoreMethods
  module LocalFlat
    def file_path
      "#{RAILS_ROOT}/public/data/#{file_name}"
    end

    def file_url
      CONFIG["url_base"] + "/data/#{file_name}"
    end

    def preview_path
      if status == "deleted"
        "#{RAILS_ROOT}/public/deleted-preview.png"
      elsif image?
        "#{RAILS_ROOT}/public/data/preview/#{md5}.jpg"
      else
        "#{RAILS_ROOT}/public/download-preview.png"
      end
    end

    def sample_path
      "#{RAILS_ROOT}/public/data/sample/" + CONFIG["sample_filename_prefix"] + "#{md5}.jpg"
    end

    def preview_url
      if image?
        CONFIG["url_base"] + "/data/preview/#{md5}.jpg"
      else
        CONFIG["url_base"] + "/download-preview.png"
      end
    end

    def store_sample_url
      CONFIG["url_base"] + "/data/sample/" + CONFIG["sample_filename_prefix"] + "#{md5}.jpg"
    end

    def delete_file
      FileUtils.rm_f(file_path)
      FileUtils.rm_f(preview_path) if image?
      FileUtils.rm_f(sample_path) if image?
    end

    def move_file
      FileUtils.mv(tempfile_path, file_path)
      FileUtils.chmod(0664, file_path)

      if image?
        FileUtils.mv(tempfile_preview_path, preview_path)
        FileUtils.chmod(0664, preview_path)
      end

      if File.exists?(tempfile_sample_path)
        FileUtils.mv(tempfile_sample_path, sample_path)
        FileUtils.chmod(0664, sample_path)
      end

      delete_tempfile
    end
  end
end
