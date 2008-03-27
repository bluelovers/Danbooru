module PostMethods
  module SampleMethods
    def tempfile_sample_path
      "#{RAILS_ROOT}/public/data/#{$PROCESS_ID}-sample.jpg"
    end

    def regenerate_sample
      return false unless image?

      if generate_sample && File.exists?(tempfile_sample_path)
        FileUtils.mkdir_p(File.dirname(sample_path), :mode => 0775)
        FileUtils.mv(tempfile_sample_path, sample_path)
        FileUtils.chmod(0775, sample_path)
        return true
      else
        return false
      end
    end

    def generate_sample
      return true unless image?
      return true unless CONFIG["image_samples"]
      return true unless (self.width && self.height)
      return true if (self.file_ext.downcase == "gif")

      size = Danbooru.reduce_to({:width => self.width, :height => self.height}, {:width => CONFIG["sample_width"], :height => CONFIG["sample_height"]}, CONFIG["sample_ratio"])

      # We can generate the sample image during upload or offline.  Use tempfile_path
      # if it exists, otherwise use file_path.
      path = tempfile_path
      path = file_path unless File.exists?(path)
      unless File.exists?(path)
        errors.add(:file, "not found")
        return false
      end

      # If we're not reducing the resolution for the sample image, only reencode if the
      # source image is above the reencode threshold.  Anything smaller won't be reduced
      # enough by the reencode to bother, so don't reencode it and save disk space.
      if size[:width] == self.width && size[:height] == self.height &&
        File.size?(path) < CONFIG["sample_always_generate_size"]
        return true
      end

      # If we already have a sample image, and the parameters havn't changed,
      # don't regenerate it.
      if size[:width] == self.sample_width && size[:height] == self.sample_height
        return true
      end

      size = Danbooru.reduce_to({:width=>self.width, :height=>self.height}, {:width=>CONFIG["sample_width"], :height=>CONFIG["sample_height"]})
      begin
        Danbooru.resize(file_ext, path, tempfile_sample_path, size, 95)
      rescue Exception => x
        errors.add "sample", "couldn't be created: #{x}"
        return false
      end

      self.sample_width = size[:width]
      self.sample_height = size[:height]
      return true
    end
  
    # Returns true if the post has a sample image.
    def has_sample?
      self.sample_width.is_a?(Integer)
    end

    # Returns true if the post has a sample image, and we're going to use it.
    def use_sample?(user = nil)
      if user && !user.show_samples?
        false
      else
        CONFIG["image_samples"] && self.has_sample?
      end
    end

    def sample_url(user = nil)
      if status != "deleted" && use_sample?(user)
        store_sample_url
      else
        file_url
      end
    end

    def get_sample_width(user = nil)
      if use_sample?(user)
        self.sample_width
      else
        self.width
      end
    end

    def get_sample_height(user = nil)
      if use_sample?(user)
        self.sample_height
      else
        self.height
      end
    end
  end
end