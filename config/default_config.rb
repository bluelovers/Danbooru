CONFIG = {}

# The version of this Danbooru.
CONFIG["version"] = "1.8.0"

# The default name to use for anyone who isn't logged in.
CONFIG["default_guest_name"] = "Anonymous"

# Set to true to require an e-mail address to register.
CONFIG["enable_account_email_validation"] = false

# Enabling this disables: tag type lookup, intersecting related tag search,
# and forum update notices. It also sets the minimum related tag cache to 
# 8 hours.
CONFIG["enable_turbo_mode"] = false

# Set to true to allow Anonymous to access anything under /post/.
CONFIG["enable_anonymous_post_access"] = false

# Set to true to allow Anonymous to upload new posts.
CONFIG["enable_anonymous_post_uploads"] = false

# Set to true to enable comments.
CONFIG["enable_comments"] = true

# Set to true to enable spam filter for new comments. This may potentially
# kill valid comments. The filter is mostly based on the number of URLs
# included in the post as well as some keywords.
CONFIG["enable_comment_spam_filter"] = true

# Set to true to allow Anonymous to access anything under /comment/.
CONFIG["enable_anonymous_comment_access"] = false

# Set to true to allow Anonymous to post comments (does not affect users 
# deliberately posting as Anonymous).
CONFIG["enable_anonymous_comment_responses"] = false

# Set to true to allow Anonymous to edit notes.
CONFIG["enable_anonymous_note_edits"] = false

# Set to true to allow users to delete notes.
CONFIG["enable_user_note_deletes"] = true

# Set to true to allow Anonymous to access anything under /wiki/.
CONFIG["enable_anonymous_wiki_access"] = true

# Set to true to allow Anonymous to edit the wiki.
CONFIG["enable_anonymous_wiki_edits"] = true

# Set to true to allow new account signups.
CONFIG["enable_signups"] = true

# Set to true to enable invites (this overrides signups).
CONFIG["enable_invites"] = true

# Set to true to enable the forum.
CONFIG["enable_forum"] = true

# Set to true to allow Anonymous to access anything under /forum/.
CONFIG["enable_anonymous_forum_access"] = false

# Set to true to allow Anonymous to post to the forum.
CONFIG["enable_anonymous_forum_posts"] = false

# Set to true to link to the Danbooru Trac on the navigation bar.
CONFIG["enable_trac_link"] = false

# Newly created users start out with this many invites.
CONFIG["starting_invite_count"] = 0

# Newly created users start at this level
CONFIG["starting_level"] = 2

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

# If enabled, this setting will cause non-safe posts to be filtered out 
# for people who don't login.
CONFIG["enable_anonymous_safe_post_mode"] = false

# This enables various caching mechanisms. You must have memcache (and 
# the memcache-client ruby gem) installed in order for caching to work.
CONFIG["enable_caching"] = false

# The server and port where the memcache client can be accessed. Only
# relevant if you enable caching.
CONFIG["memcache_servers"] = ["localhost:4000"]

# This config only comes into play if you enable caching. There are two 
# levels of caching:
# 1: Only cache actions visited by anonymous users.
# 2: Cache actions, even if the user is logged in. This necessitates 
# deactivating a few features (such as blacklists).
CONFIG["cache_level"] = 1

# Any post rated safe that has one of the following tags will
# automatically be rated questionable.
CONFIG["questionable_tags"] = %w(no_panties nude pussy penis cum nipples erect_nipples anal vibrator dildo masturbation oral_sex sex paizuri penetration guro rape yaoi asshole footjob handjob cameltoe blowjob cunnilingus anal_sex topless)

# After a post receives this many posts, new comments will no longer
# bump the post in comment/index.
CONFIG["comment_threshold"] = 40
