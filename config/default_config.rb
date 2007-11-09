CONFIG = {}

# The version of this Danbooru.
CONFIG["version"] = "1.10.0"

# The default name to use for anyone who isn't logged in.
CONFIG["default_guest_name"] = "Anonymous"

# Set to true to require an e-mail address to register.
CONFIG["enable_account_email_validation"] = false

# This is a salt used to make dictionary attacks on account passwords harder.
CONFIG["password_salt"] = "choujin-steiner"

# Enabling this disables: tag type lookup, intersecting related tag search,
# and forum update notices. It also sets the minimum related tag cache duration
# to 8 hours.
CONFIG["enable_turbo_mode"] = false

# Set to true to allow new account signups.
CONFIG["enable_signups"] = true

# Enable this if you want explicit posts to be hidden from unprivileged members
# and anonymous visitors.
CONFIG["hide_explicit_posts"] = false

# Newly created users start at this level. Set this to 3 if you want everyone
# to start out as a privileged member.
CONFIG["starting_level"] = 2

# New users will start out with this many invites.
CONFIG["starting_invite_count"] = 2

# What method to use to store images.
# local_flat: Store every image in one directory.
# local_hierarchy: Store every image in a hierarchical directory,
# based on the post's MD5 hash. On some file systems this may be
# faster.
# amazon_s3: Save files to an Amazon S3 account.
# remote_hierarchy: Some images will be stored on separate image
# servers using a hierarchical directory.
CONFIG["image_store"] = :local_flat

# Only used when image_store == :remote_hierarchy.
# An array of image servers (use http://domain.com format).
CONFIG["image_servers"] = []

# These three configs are only relevant if you're using the Amazon S3 
# image store.
CONFIG["amazon_s3_access_key_id"] = ""
CONFIG["amazon_s3_secret_access_key"] = ""
CONFIG["amazon_s3_bucket_name"] = ""

# This enables various caching mechanisms. You must have memcache (and 
# the memcache-client ruby gem) installed in order for caching to work.
CONFIG["enable_caching"] = false

# The server and port where the memcache client can be accessed. Only
# relevant if you enable caching.
CONFIG["memcache_servers"] = ["localhost:4000"]

# Any post rated safe that has one of the following tags will
# automatically be rated questionable.
CONFIG["questionable_tags"] = %w(no_panties nude pussy penis cum anal vibrator dildo masturbation oral_sex sex paizuri penetration guro rape yaoi asshole footjob handjob cameltoe blowjob cunnilingus anal_sex topless)

# After a post receives this many posts, new comments will no longer
# bump the post in comment/index.
CONFIG["comment_threshold"] = 40

# Members cannot post more than X posts in a day.
CONFIG["member_post_limit"] = 16

# Members cannot post more than X comments in an hour.
CONFIG["member_comment_limit"] = 2

# This allows posts to have parent-child relationships. However, this 
# requires manually updating the post counts stored in table_data by
# periodically running the script/maintenance script.
CONFIG["enable_parent_posts"] = false
