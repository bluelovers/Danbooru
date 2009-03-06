CONFIG = {}

# The version of this Danbooru.
CONFIG["version"] = "1.16.0"

# The default name to use for anyone who isn't logged in.
CONFIG["default_guest_name"] = "Anonymous"

# This is a salt used to make dictionary attacks on account passwords harder.
CONFIG["password_salt"] = "choujin-steiner"

# Set to true to allow new account signups.
CONFIG["enable_signups"] = true

# Newly created users start at this level. Set this to 30 if you want everyone
# to start out as a privileged member.
CONFIG["starting_level"] = 20

# What method to use to store images.
# local_flat: Store every image in one directory.
# local_hierarchy: Store every image in a hierarchical directory, based on the post's MD5 hash. On some file systems this may be faster.
# local_flat_with_amazon_s3_backup: Store every image in a flat directory, but also save to an Amazon S3 account for backup.
# amazon_s3: Save files to an Amazon S3 account.
# remote_hierarchy: Some images will be stored on separate image servers using a hierarchical directory.
CONFIG["image_store"] = :local_flat

# Only used when image_store == :remote_hierarchy. An array of image servers (use http://domain.com format).
CONFIG["image_servers"] = []

# Enables image samples for large images. NOTE: if you enable this, you must manually create a public/data/sample directory.
CONFIG["image_samples"] = true

# The maximum dimensions and JPEG quality of sample images.
CONFIG["sample_width"] = 1400
CONFIG["sample_height"] = 1000 # Set to nil if you never want to scale an image to fit on the screen vertically
CONFIG["sample_quality"] = 90

# Resample the image only if the image is larger than sample_ratio * sample_dimensions.
CONFIG["sample_ratio"] = 1.25

# A prefix to prepend to sample files
CONFIG["sample_filename_prefix"] = ""

# Files over this size will always generate a sample, even if already within
# the above dimensions.
CONFIG["sample_always_generate_size"] = 512*1024

# These three configs are only relevant if you're using the Amazon S3 image store.
CONFIG["amazon_s3_access_key_id"] = ""
CONFIG["amazon_s3_secret_access_key"] = ""
CONFIG["amazon_s3_bucket_name"] = ""

# The server and port where the memcache client can be accessed. Only relevant if you enable caching.
CONFIG["memcache_servers"] = ["localhost:4000"]

# After a post receives this many posts, new comments will no longer bump the post in comment/index.
CONFIG["comment_threshold"] = 40

# Members cannot post more than X posts in a day.
CONFIG["member_post_limit"] = 16

# Members cannot post more than X comments in an hour.
CONFIG["member_comment_limit"] = 2

# Defines the various user levels. You should not remove any of the default ones. When Danbooru starts up, the User model will have several methods automatically defined based on what this config contains. For this reason you should only use letters, numbers, and spaces (spaces will be replaced with underscores). Example: is_member?, is_member_or_lower?, is_member_or_higher?
CONFIG["user_levels"] = {
  "Unactivated" => 0,
  "Blocked" => 10,
  "Member" => 20,
  "Privileged" => 30,
  "Contributor" => 33,
  "Janitor" => 35,
  "Mod" => 40,
  "Admin" => 50
}

# Defines the various tag types. You can also define shortcuts.
CONFIG["tag_types"] = {
  "General" => 0,
  "Artist" => 1,
  "Copyright" => 3,
  "Character" => 4,
  
  "general" => 0,
  "artist" => 1,
  "copyright" => 3,
  "character" => 4,
  "art" => 1,
  "copy" => 3,
  "char" => 4
}

# Determine who can see a post. Note that since this is a block, return won't work. Use break.
CONFIG["can_see_post"] = lambda do |user, post|
  true
  
  # Some examples:
  #
  # Hide post if user isn't privileged and post is not safe:
  # post.rating != "e" || user.is_privileged_or_higher?
  #
  # Hide post if user isn't a mod and post has the loli tag:
  # !post.has_tag?("loli") || user.is_mod_or_higher?
end

# Determines who can see ads. Note that since this is a block, return won't work. Use break.
CONFIG["can_see_ads"] = lambda do |user|
  # By default, only show ads to non-priv users.
  user.is_member_or_lower?
  
  # Show no ads at all
  # false
end

# Defines the default blacklists for new users.
CONFIG["default_blacklists"] = [
#  "rating:e loli",
#  "rating:e shota",
]

# This is required for Rails 2.0.
CONFIG["session_secret_key"] = "This should be at least 30 characters long"

# Users cannot search for more than X regular tags at a time.
CONFIG["tag_query_limit"] = 6

# Set this to insert custom CSS or JavaScript files into your app.
CONFIG["custom_html_headers"] = nil

# Set this to true to hand off time consuming tasks (downloading files, resizing images, any sort of heavy calculation) to a separate process.
CONFIG["enable_asynchronous_tasks"] = false

# Max number of posts to cache
CONFIG["tag_subscription_post_limit"] = 200

# Max number of tag subscriptions per user
CONFIG["max_tag_subscriptions"] = 5

CONFIG["load_average_threshold"] = nil
