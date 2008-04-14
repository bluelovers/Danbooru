module PostMethods
  module ImageStoreMethods
    def image_store(type)
      case type
      when :local_flat
        include PostMethods::ImageStoreMethods::LocalFlat
      
      when :local_flat_with_amazon_s3_backup
        include PostMethods::ImageStoreMethods::LocalFlatWithAmazonS3Backup

      when :local_hierarchy
        include PostMethods::ImageStoreMethods::LocalHierarchy

      when :remote_hierarchy
        include PostMethods::ImageStoreMethods::RemoteHierarchy

      when :amazon_s3
        include PostMethods::ImageStoreMethods::AmazonS3
      end
    end
  end
end
