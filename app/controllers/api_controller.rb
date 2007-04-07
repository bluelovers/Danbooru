# A REST-based API that makes scripting Danbooru simple. All methods are accessed via HTTP methods like GET and POST. As a rule, any action that changes state requires a POST, while any action that doesn't change state requires a GET. The general URL format is: http://danbooru.donmai.us/api/{action}?{param1}&{param2}
# For any action that you want to login for, you can supply a login and password parameter. 

class ApiController < ApplicationController
	verify :method => :post, :only => [:add_post, :change_post, :lock_post, :score_post, :del_favorite, :add_favorite]
	verify :method => :post, :only => [:mark_comment, :add_comment] if CONFIG["enable_comments"]
	before_filter :set_api_flag
	after_filter :save_tags_to_cookie, :only => [:add_post, :change_post]

# Adds a post to the database.
#
# === Parameters
# * file: file as a multipart form
# * source: source url
# * title: title
# * tags: list of tags as a string, delimited by whitespace
# * md5: MD5 hash of upload in hexadecimal format
# * rating: rating of the post. can be explicit, questionable, or safe.
#
# === Notes
# * The only necessary parameter is +tags+ and either +file+ or +source+.
# * If an account is not supplied or if it doesn't authenticate, he post will be added anonymously.
# * If the md5 parameter is supplied and does not match the hash of what's on the server, the post is rejected.
#
# === Response
# * X-Danbooru-Location set to the URL for newly uploaded post.
	def add_post
		if !CONFIG["allow_anonymous_posts"] && current_user() == nil
			render :text => "You must be logged in to upload posts", :status => 403
			return
		end

		unless params["tags"]
			render :text => "incomplete upload", :status => 500
			return
		end

		post_hash = {:file => params["file"], :source => params["source"], :rating => params["rating"], :tags => params["tags"]}
		@post = Post.create(post_hash.merge(:user_id => session[:user_id], :ip_addr => request.remote_ip, :updater_user_id => session[:user_id], :updater_ip_addr => request.remote_ip))

		if @post.errors.empty?
			if params["md5"] and params["md5"].downcase != @post.md5
				response.headers["X-Danbooru-Errors"] = "mismatched md5"
				render :text => "mismatched md5", :status => 409
				@post.destroy
			else
				response.headers["X-Danbooru-Location"] = url_for(:controller => "post", :action => "show", :id => @post.id)
				render :nothing => true
			end
		elsif @post.errors.invalid?(:md5)
			p = Post.find_by_md5(@post.md5)
			p.update_attributes(:tags => (p.cached_tags.to_s + " " + params["tags"]), :updater_user_id => session[:user_id], :updater_ip_addr => request.remote_ip)
			response.headers["X-Danbooru-Errors"] = "duplicate"
			response.headers["X-Danbooru-Location"] = url_for(:controller => "post", :action => "show", :id => p.id)
			render :text => "duplicate", :status => 409
		else
			response.headers["X-Danbooru-Errors"] = "other"
			render_error(@post)
		end
	end

# Changes a post.
#
# === Parameters
# * id: the post's id number
# * title: the new title
# * tags: the new tags
# * rating: the rating. can be: explicit, safe, questionable
#
# === Notes
# * Only the id parameter is required.
# * You can leave title, tags, or rating empty to keep the original value.
#
# === Response
# * 200: Post was successfully changed.
# * 500: Internal server error. Response body contains a dump of the invalid post.
	def change_post
		@post = Post.find(params["id"])
		
		if @post.update_attributes(:tags => params["tags"], :updater_user_id => session[:user_id], :updater_ip_addr => request.remote_ip, :rating => params["rating"])
			render :nothing => true
		else
			response.headers["X-Danbooru-Errors"] = "internal"
			render_error(@post)
		end
	end

# Find all posts that match the search criteria. Posts will be ordered by id descending.
#
# === Parameters
# * md5: md5 hash to search for (comma delimited)
# * id: id to search for (comma delimited)
# * tags: what tags to search for
# * limit: limit
# * offset: offset
# * after_id: limit results to posts added after this id
	def find_posts
		if params[:md5]
			@posts = Post.find(:all, :conditions => ["md5 in (?)", params[:md5].downcase.split(",")])
		elsif params[:id]
			@posts = Post.find(:all, :conditions => ["id in (?)", params[:id].split(",")])
		else
			params[:limit] ||= 100
			params[:limit] = 100 if params[:limit].to_i > 100
			@posts = Post.find_by_sql(Post.generate_sql(params[:tags] || params[:query], :limit => params[:limit], :offset => params[:offset], :order => "p.id DESC"))
		end
	end

# Locks a post's rating or notes.
#
# === Parameters
# * id: the post id number
# * rating: set to 1 to lock the rating
# * note: set to 1 to lock the note
	def lock_post
		p = Post.find(params["id"])
		if params["rating"]
			p.update_attribute(:is_rating_locked, true)
		elsif params["note"]
			p.update_attribute(:is_note_locked, true)
		end

		render :nothing => true
	end

	def find_related_tags
		if params["url"]
			escaped_url = File.dirname(params["url"]).gsub(/\\/, '\\\\').gsub(/%/, '\\%').gsub(/_/, '\\_') + "%"
			@tags = Tag.find(:all, :conditions => ["id IN (SELECT tag_id FROM posts_tags WHERE post_id IN (SELECT id FROM posts WHERE source LIKE ? ESCAPE '\\\\')) AND tag_type = ?", escaped_url, Tag::TYPE_ARTIST], :order => "name", :limit => 1, :select => "name").map {|i| i.name}
		elsif params["tags"]
			if params["artist"]
				tag_type = Tag::TYPE_ARTIST
			elsif params["char"]
				tag_type = Tag::TYPE_CHARACTER
			elsif params["copyright"]
				tag_type = Tag::TYPE_COPYRIGHT
			else
				tag_type = nil
			end

			foo = params["tags"].scan(/[^ ,]+/)
			patterns, foo = foo.partition {|i| i.include?("*")}

			@tags = []

			patterns.each do |t|
				@tags += Tag.find(:all, :select => "name", :conditions => ["name LIKE ? ESCAPE '\\\\'", t.gsub(/\\/, '\\\\').gsub(/%/, '\\%').gsub(/_/, '\\_').gsub(/\*/, '%')]).map {|i| i.name}
			end

			foo.each do |t|
				if tag_type.nil?
					@tags += Tag.find_related(TagAlias.to_aliased(t)).map {|i| i[0]}
				else
					@tags += Tag.find(:all, :conditions => ["id IN (SELECT tag_id FROM posts_tags WHERE post_id IN (SELECT post_id FROM posts_tags WHERE tag_id = (SELECT id FROM tags WHERE name = ?))) AND tag_type = ?", TagAlias.to_aliased(t), tag_type], :order => "name", :select => "name", :limit => 25).map {|i| i.name}
				end
			end
		else
			@tags = []
		end

		render :text => @tags.sort.uniq.join(" ")
	end

# Find all tags that match the search criteria.
#
# === Parameters
# * id: A comma delimited list of tag id numbers.
# * name: A comma delimited list of tag names.
# * tags: any typical tag query. See Tag#parse_query for details.
# * after_id: limit results to tags with an id number after +after_id+. Useful if you only want to refresh a local copy.
	def find_tags
		if params["id"]
			@tags = Tag.find(:all, :conditions => ["id in (?)", params["id"].split(",")])
		elsif params["name"]
			@tags = Tag.find(:all, :conditions => ["name IN (?)", params["name"].split(",")])
		else
			@tags = Tag.find(:all, :conditions => ["post_count > 0 AND id >= ?", params["after_id"] || 0], :order => "id DESC")
		end
	end

# Finds all wiki pages that match the search criteria.
#
# === Parameters
# * title: the exact title of the wiki page.
	def find_wiki
		if params["title"]
			@wiki = WikiPage.find_page(params["title"])
		end
	end

if CONFIG["enable_comments"]
# Finds comments.
#
# === Parameters
# * id: the id of the comment
# * post_id: the id of the post
#
# === Notes
# * You must specify either post_id or id. post_id takes precedence.
	def find_comments
		if params["id"]
			@comments = Comment.find(:all, :conditions => ["id = ?", params["id"]])
		elsif params["post_id"]
			@comments = Comment.find(:all, :conditions => ["post_id = ?", params["post_id"]])
		end
	end

# Adds a comment to a post.
#
# === Parameters
# * body: the body of the comment
# * post_id: the post id
# * login: your login
# * password: your password
#
# === Response
# * 200: success
# * 500: error. response body will the the error message.
	def add_comment
		c = Comment.new(:body => params["body"], :post_id => params["post_id"], :user_id => (current_user().id rescue nil))
		if c.save
			render :nothing => true
		else
			render_error(c)
		end
	end

# Marks a comment as noise
#
# === Parameters
# * id: The comment id
	def mark_comment
		c = Comment.find(params["id"])
		if c.signal_level == 2
			render :text => "This comment has already been marked", :status => 500
		else
			c.spam!
			render :nothing => true
		end
	end
end # if CONFIG["enable_comments"]

# Scores a post.
#
# === Parameters
# * id: the post id
# * score: the score. can be: 1, -1
#
# === Response
# * 200: success
# * 409: already voted
	def score_post
		p = Post.find(params["id"])
		score = params["score"].to_i

		unless score == 1 || score == -1
			render :text => "invalid score", :status => 500
			return
		end

		if p.vote!(score, @request.remote_ip)
			render :nothing => true
		else
			render :text => "already voted", :status => 500
		end
	end

# Returns information about a user
#
# === Parameters
# * id: id number of the user
# * name: name of the user
#
# === Response
# An XML file
	def find_user
		@user = nil

		if params["id"]
			@user = User.find(params["id"])
		elsif params["name"]
			@user = User.find_by_name(params["name"])
		end
	end

# Returns the tag history for a given post id, or every post if an id is not specified.
#
# === Parameters
# * post_id: the post id number. You can input a comma-delimited list of ids to retrieve tag changes for all of them.
# * after_id: get every tag change after this id
	def find_tag_history
		if params["post_id"]
			@changes = PostTagHistory.find(:all, :conditions => ["post_id in (?)", params["id"].split(",")])
		else
			@changes = PostTagHistory.find(:all, :conditions => ["id >= ?", params["after_id"]])
		end
	end

	def add_favorite
		user = current_user()
		if user
			begin
				user.add_favorite(params["id"])
				render :nothing => true
			rescue User::AlreadyFavoritedError
				render :text => "duplicate", :status => 409
			end
		else
			render :text => "not logged in", :status => 500
		end
	end

	def del_favorite
		user = current_user()
		if user
			user.del_favorite(params["id"])
			render :nothing => true
		else
			render :text => "not logged in", :status => 403
		end
	end

	protected

	# Sets a flag to indicate this request is an API call. Useful for some library functions.
	def set_api_flag
		@is_api_request = true
	end
end
