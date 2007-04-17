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

# Set to true to allow Anonymous to post to the forum.
CONFIG["enable_anonymous_forum_posts"]			= false

# Set to true to enable server-side tag blacklists.
CONFIG["enable_tag_blacklists"]					= false

# Set to true to enable server-side user blacklists.
CONFIG["enable_user_blacklists"]				= false

# Set to true to enable server-side post thresholds
CONFIG["enable_post_thresholds"]				= false

# Set to true to enable the artist/character/copyright descriptors
# when displaying tag lists. This is informative but adds strain to
# the database.
CONFIG["enable_tag_type_lookups"]				= false

# Set to true to show only the related tags of the intersection
# when searching for multiple tags. This relies on an expensive
# database query and probably shouldn't be enabled if you're
# expecting more than a dozen concurrent connections.
CONFIG["enable_related_tag_intersection"]		= false

# Set to true to link to the Danbooru Trac on the navigation bar.
CONFIG["enable_trac_link"]						= false

# If this is enabled, whenever a forum topic is posted or
# updated and the user hasn't seen it yet, that topic's title
# will be displayed in bold, and the Forum link on the main
# navigation bar will also be bold. This relies on a nontrivial
# database call, however. For forums with less than 10,000
# posts it shouldn't really be an issue, but to squeeze out
# every ounce of performance you can disable it.
CONFIG["enable_forum_update_notices"]			= true

# Newly created users start out with this many invites.
CONFIG["starting_invite_count"]					= 0

# Minimum number of hours to cache related tags
CONFIG["min_related_tags_cache_duration"]		= 8
