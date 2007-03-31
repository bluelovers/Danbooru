CONFIG = {}

# The version of this Danbooru.
CONFIG["version"]								= "1.5.0"

# The default name to use for anyone who isn't logged in.
CONFIG["default_guest_name"]					= "Anonymous"

# Set to true to require an e-mail address to register.
CONFIG["enable_account_email_validation"]		= false

# Set to true to allow Anonymous to access anything under /post/.
CONFIG["enable_anonymous_post_access"]			= false

# Set to true to allow Anonymous to upload new posts.
CONFIG["enable_anonymous_post_uploads"]			= false

# Set to true to enable comments.
CONFIG["enable_comments"]						= true

# Set to true to enable spam filter for new comments. This may potentially
# kill valid comments. The filter is mostly based on the number of URLs
# included in the post as well as some keywords.
CONFIG["enable_comment_spam_filter"]			= true

# Set to true to allow Anonymous to access anything under /comment/.
CONFIG["enable_anonymous_comment_access"]		= false

# Set to true to allow Anonymous to post comments (does not affect users 
# deliberately posting as Anonymous).
CONFIG["enable_anonymous_comment_responses"]	= false

# Set to true to allow Anonymous to edit notes.
CONFIG["enable_anonymous_note_edits"]			= false

# Set to true to allow users to delete notes.
CONFIG["enable_user_note_deletes"]				= true

# Set to true to allow Anonymous to access anything under /wiki/.
CONFIG["enable_anonymous_wiki_access"]			= true

# Set to true to allow Anonymous to edit the wiki.
CONFIG["enable_anonymous_wiki_edits"]			= true

# Set to true to allow new account signups.
CONFIG["enable_signups"]						= true

# Set to true to enable invites (this overrides signups).
CONFIG["enable_invites"]						= true

# Set to true to enable the forum.
CONFIG["enable_forum"]							= true

# Set to true to allow Anonymous to access anything under /forum/.
CONFIG["enable_anonymous_forum_access"]			= false

# Set to true to Allow Anonymous to post to the forum.
CONFIG["enable_anonymous_forum_posts"]			= false

# Set to true to enable server-side tag blacklists.
CONFIG["enable_tag_blacklists"]					= false

# Set to true to enable server-side user blacklists.
CONFIG["enable_user_blacklists"]				= false

# Set to true to enable server-side post thresholds
CONFIG["enable_post_thresholds"]				= false

# Set to true to allow users to register using OpenID (compatible 
# with regular signups and invites).
CONFIG["enable_openid"]							= false

# Set to true to enable the artist/character/copyright descriptors
# when displaying tag lists. This is informative but adds strain to
# the database.
CONFIG["enable_tag_type_lookups"]				= true
