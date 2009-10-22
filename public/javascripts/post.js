Post = {
  mod_queue: null,
  posts: new Hash(),
  pending_update_count: 0,
  blacklist_options: { replace: true },
  
  notice_update: function(increase_or_decrease) {
    if (increase_or_decrease == "inc") {
      Post.pending_update_count += 1
      notice("Updating posts (" + Post.pending_update_count + " pending)...")
    } else {
      Post.pending_update_count -= 1
      
      if (Post.pending_update_count == 0) {
        notice("Posts updated")
      } else {
        notice("Updating posts (" + Post.pending_update_count + " pending)...")        
      }
    }
  },

	find_similar: function() {
		var old_source_name = $("post_source").name
		var old_file_name = $("post_file").name
		var old_target = $("edit-form").target
		var old_action = $("edit-form").action

		$("post_source").name = "url"
		$("post_file").name = "file"
		$("edit-form").target = "_blank"
		$("edit-form").action = "http://danbooru.iqdb.hanyuu.net/"

		$("edit-form").submit()		
		
		$("post_source").name = old_source_name
		$("post_file").name = old_file_name
		$("edit-form").target = old_target
		$("edit-form").action = old_action
	},

  mass_moderate: function(action) {
    Post.notice_update("inc")
    
    new Ajax.Request("/post/moderate.json", {
      parameters: {"id": Post.mod_queue.join(","), "commit": action},
      
      onComplete: function(resp) {
        Post.notice_update("dec")
      }
    })
    
    Post.mod_queue.each(function(x) {
      if ($("mod-row-" + x)) {
        $("mod-row-" + x).hide()
      }      
    })
    
    Post.mod_queue = $A([])
  },

  moderate: function(post_id, action) {
    Post.notice_update("inc")
    var params = {}
    params["id"] = post_id
    params["commit"] = action

    if (Post.mod_queue) {
      Post.mod_queue = Post.mod_queue.without(post_id)      
    }
    
    if (action == "Delete") {
      params["reason"] = prompt("Enter a reason")
      
      if (params["reason"] == null) {
        return
      }
    }
    
    new Ajax.Request("/post/moderate.json", {
      parameters: params,
      
      onComplete: function(resp) {
        var resp = resp.responseJSON
        Post.notice_update("dec")
        
        if (resp.success) {
          if ($("p" + post_id)) {
            $("p" + post_id).down("img").removeClassName("pending")
          }
          if ($("pending-notice")) {
            $("pending-notice").hide()
          }
        } else {
          notice("Error: " + resp.reason)
        }
      }
    })

    if ($("mod-row-" + post_id)) {
      $("mod-row-" + post_id).hide()
    } else if (window.opener && !window.opener.closed && window.opener.$("mod-row-" + post_id)) {
      window.opener.$("mod-row-" + post_id).hide()
    }
  },

  update: function(post_id, params) {
    Post.notice_update("inc")
    params["id"] = post_id

    new Ajax.Request('/post/update.json', {
      parameters: params,

      onComplete: function(resp) {
        Post.notice_update("dec")
        var resp = resp.responseJSON

        if (resp.success) {
          // Update the stored post.
          Post.register(resp.post)
        } else {
          notice('Error: ' + resp.reason)
        }
      }
    })
  },

  observe_text_area: function(field_id) {
    $(field_id).observe("keydown", function(e) {
      if (e.keyCode == Event.KEY_RETURN) {
        this.up("form").submit()
        e.stop()
      }
    })
  },

  vote: function(score, id) {
    Post.notice_update("inc")

    new Ajax.Request("/post/vote.json", {
      parameters: {
        "id": id,
        "score": score
      },
    
      onComplete: function(resp) {
        Post.notice_update("dec")
        var resp = resp.responseJSON

        if (resp.success) {
          $("post-score-" + resp.post_id).update(resp.score)
        } else {
          notice("Error: " + resp.reason)
        }
      }
    })
  },

  flag: function(id) {
    var reason = prompt("Why should this post be reconsidered for moderation?")
    
    if (reason == null) {
      return false
    }
    
    new Ajax.Request("/post/flag.json", {
      parameters: {
        "id": id,
        "reason": reason
      },
    
      onComplete: function(resp) {
        var resp = resp.responseJSON

        if (resp.success) {
          notice("Post was resent to moderation queue")
        } else {
          notice("Error: " + resp.reason)
        }
      }
    })
  },

  register: function(post) {
    post.tags = post.tags.match(/\S+/g)
    post.match_tags = post.tags.clone()
    post.match_tags.push("rating:" + post.rating.charAt(0))
    post.match_tags.push("status:" + post.status)
    post.match_tags.push("user:" + post.author)
    this.posts.set(post.id, post)
  },

  blacklists: [],

  is_blacklisted: function(post_id) {	// you can't have side effects like ++b.hits in a method called "is_blacklisted", ffs
    var post = this.posts.get(post_id)
    var has_tag = post.match_tags.member.bind(post.match_tags)
    return Post.blacklists.any(function(b) {
      return (b.require.all(has_tag) && !b.exclude.any(has_tag))
    })
  },

  apply_blacklists: function() {	
    Post.blacklists.each(function(b) { b.hits = 0 })

    var count = 0
    Post.posts.each(function(pair) {
      var thumbs = $$("#p" + pair.key)
      if (thumbs.length == 0) return
      var post = pair.value
      var has_tag = post.match_tags.member.bind(post.match_tags)
      post.blacklisted = []
      Post.blacklists.each(function(b) {
        if (b.require.all(has_tag) && !b.exclude.any(has_tag)) {
          b.hits++
          if (!b.disabled) post.blacklisted.push(b)
        }
      })
      bld = post.blacklisted.length > 0

      count += bld
      thumbs.each(function(thumb) {
        if (Post.blacklist_options.replace) {
          var img = thumb.down('img')
          if (bld) {
            img.src   = "/blacklisted-preview.png"
            img.width = img.height = 150
	  } else {
            img.src    = post.preview_url
            img.width  = post.preview_width
            img.height = post.preview_height
	  }
          thumb.removeClassName('blacklisted');
        } else {
          if (bld)
            thumb.addClassName('blacklisted');
          else
            thumb.removeClassName('blacklisted');
        }
      });
    })

    if (Post.countText)
      Post.countText.textContent = count
    return count
  },

  init_blacklisted: function(options) {
    Post.blacklist_options = Object.extend(Post.blacklist_options, options)
    var bl_entries = Cookie.raw_get("blacklisted_tags").split(/[&,]/)
    bl_entries.each(function(val) {
        var s = Cookie.unescape(val).replace(/(rating:[qes])\w+/, "$1")
        var tags = s.match(/\S+/g)
        if (!tags) return
        var b = { tags: tags, require: [], exclude: [], disabled: false, hits: 0 }
        tags.each(function(tag) {
          if (tag.charAt(0) == '-') b.exclude.push(tag.slice(1))
          else b.require.push(tag)
        })
        Post.blacklists.push(b)
    })

    var sidebar = $("blacklisted-sidebar")
    if (!sidebar) {
      Post.apply_blacklists();
      return;
    }
  
    var blacklist_count = $("blacklist-count")
    if (blacklist_count)
      Post.countText = blacklist_count.appendChild(document.createTextNode(""));

    if (!Post.apply_blacklists()) {
      sidebar.hide()
      return
    }

    sidebar.show()

    /* Keep focus from going to the item on click. */
    sidebar.observe("mousedown", function(event) { event.stop() })

    var list = $("blacklisted-list")
    Post.blacklists.each(function(b) {
      if (!b.hits)
        return

      var li = list.appendChild(document.createElement("li"))
      li.className = "blacklisted-tags"
      var a = li.appendChild(document.createElement("a"))
      a.href = "#"
      var expand = a.appendChild(document.createTextNode("»"));

      a.observe("click", function(event) {
        b.disabled = !b.disabled
        a.className = b.disabled? "blacklisted-tags-disabled":"blacklisted-tags"
        Post.apply_blacklists()
        event.stop()
      });

      a.appendChild(document.createTextNode(" "));
      var tags = a.appendChild(document.createTextNode(b.tags.join(" ")));
      li.appendChild(document.createTextNode(" "));
      var span = li.appendChild(document.createElement("span"))
      span.className = "post-count"
      span.appendChild(document.createTextNode(b.hits));
    })
  },

  resize_image: function() {
    var img = $("image");

    if ((img.scale_factor == 1) || (img.scale_factor == null)) {
      img.original_width = img.width;
      img.original_height = img.height;
      var client_width = $("right-col").clientWidth - 15;
      var client_height = $("right-col").clientHeight;

      if (img.width > client_width) {
        var ratio = img.scale_factor = client_width / img.width;
        img.width = img.width * ratio;
        img.height = img.height * ratio;
      }
    } else {
      img.scale_factor = 1;
      img.width = img.original_width;
      img.height = img.original_height;
    }
  
    if (window.Note) {
      for (var i=0; i<window.Note.all.length; ++i) {
        window.Note.all[i].adjustScale()
      }
    }
  },
  
  highres: function() {
    var img = $("image");
    
    if (img.src == $("highres").href) {
      return;
    }

    // un-resize
    if ((img.scale_factor != null) && (img.scale_factor != 1)) {
      Post.resize_image();
    }

    var f = function() {
      img.stopObserving("load")
      img.stopObserving("error")
      img.height = img.getAttribute("orig_height");
      img.width = img.getAttribute("orig_width");
      img.src = $("highres").href;

      if (window.Note) {
        window.Note.all.invoke("adjustScale")
      }
    }
    
    img.observe("load", f)
    img.observe("error", f)

    // Clear the image before loading the new one, so it doesn't show the old image
    // at the new resolution while the new one loads.  Hide it, so we don't flicker
    // a placeholder frame.
    $("resized_notice").hide()
    img.height = img.width = 0
    img.src = "about:blank"
  }
}
