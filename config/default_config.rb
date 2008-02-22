CONFIG = {}

# The version of this Danbooru.
CONFIG["version"] = "1.13.0"

# The default name to use for anyone who isn't logged in.
CONFIG["default_guest_name"] = "Anonymous"

# Set to true to require an e-mail address to register.
CONFIG["enable_account_email_activation"] = false

# This is a salt used to make dictionary attacks on account passwords harder.
CONFIG["password_salt"] = "choujin-steiner"

# Set to true to allow new account signups.
CONFIG["enable_signups"] = true

# Newly created users start at this level. Set this to 3 if you want everyone
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

# These three configs are only relevant if you're using the Amazon S3 image store.
CONFIG["amazon_s3_access_key_id"] = ""
CONFIG["amazon_s3_secret_access_key"] = ""
CONFIG["amazon_s3_bucket_name"] = ""

# This enables various caching mechanisms. You must have memcache (and the memcache-client ruby gem) installed in order for caching to work.
CONFIG["enable_caching"] = false

# Enabling this will cause Danbooru to cache things longer:
# - On post/index, any page after the first 10 will be cached for 3-7 days.
# - post/show is cached
CONFIG["enable_aggressive_caching"] = false

# The server and port where the memcache client can be accessed. Only relevant if you enable caching.
CONFIG["memcache_servers"] = ["localhost:4000"]

# Any post rated safe or questionable that has one of the following tags will automatically be rated explicit.
CONFIG["explicit_tags"] = %w(pussy penis cum anal vibrator dildo masturbation oral_sex sex paizuri penetration guro rape asshole footjob handjob blowjob cunnilingus anal_sex)

# After a post receives this many posts, new comments will no longer bump the post in comment/index.
CONFIG["comment_threshold"] = 40

# Members cannot post more than X posts in a day.
CONFIG["member_post_limit"] = 16

# Members cannot post more than X comments in an hour.
CONFIG["member_comment_limit"] = 2

# This allows posts to have parent-child relationships. However, this requires manually updating the post counts stored in table_data by periodically running the script/maintenance script.
CONFIG["enable_parent_posts"] = false

# Show only the first page of post/index to visitors.
CONFIG["show_only_first_page"] = false

CONFIG["enable_reporting"] = false

# Enable some web server specific optimizations. Possible values include: apache, nginx, lighttpd.
CONFIG["web_server"] = "apache"

# Show a link to Trac.
CONFIG["enable_trac"] = true

# Defines the various user levels. You should not remove any of the default ones. When Danbooru starts up, the User model will have several methods automatically defined based on what this config contains. For this reason you should only use letters, numbers, and spaces (spaces will be replaced with underscores). Example: is_member?, is_member_or_lower?, is_member_or_higher?
CONFIG["user_levels"] = {
  "Unactivated" => 0,
  "Blocked" => 10,
  "Member" => 20,
  "Privileged" => 30,
  "Mod" => 40,
  "Admin" => 50
}

# Defines the various tag types. You can also define shortcuts.
CONFIG["tag_types"] = {
  "General" => 0,
  "Artist" => 1,
  "Copyright" => 3,
  "Character" => 4,
  
  "art" => 1,
  "copy" => 3,
  "char" => 4
}

# Determine who can see a post. Note that since this is a block, return won't work. Use break.
CONFIG["can_see_post"] = lambda do |user, post|
  # By default, only deleted posts are hidden.
  break post.status != 'deleted'
  
  # Some examples:
  #
  # Hide post if user isn't privileged and post is not safe:
  # break post.rating != 'e' || (user != nil && user.privileged?)
  #
  # Hide post if user isn't a mod and post has the loli tag:
  # break post.has_tag?("loli") 
end

# Determines who can see ads. Note that since this is a block, return won't work. Use break.
CONFIG["can_see_ads"] = lambda do |user|
  # By default, only show ads to non-priv users.
  break user == nil || user.is_member_or_lower?
end

# Enable the artists interface.
CONFIG["enable_artists"] = true

# This is required for Rails 2.0.
CONFIG["session_secret_key"] = "This should be at least 30 characters long"

# Users cannot search for more than X regular tags at a time.
CONFIG["tag_query_limit"] = 6

# Set this to insert custom CSS or JavaScript files into your app.
CONFIG["custom_html_headers"] = nil
