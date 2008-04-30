Post = {
  posts: new Hash(),

  approve: function(post_id) {
    notice("Approving post #" + post_id)
    var params = {}
    params["ids[" + post_id + "]"] = "1"
    params["commit"] = "Approve"
    
    new Ajax.Request("/post/moderate.json", {
      parameters: params,
      
      onComplete: function(resp) {
        var resp = resp.responseJSON
        
        if (resp.success) {
          notice("Post approved")
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
  },

  update: function(post_id, params) {
    notice('Updating post #' + post_id)
    params["id"] = post_id

    new Ajax.Request('/post/update.json', {
      parameters: params,

      onComplete: function(resp) {
        var resp = resp.responseJSON

        if (resp.success) {
          notice('Post updated')

          // Update the stored post.
          Post.register(resp.post)
        } else {
          notice('Error: ' + resp.reason)
        }
      }
    })
  },

  init_score: function(post_id, score) {
    var post = Post.posts.get(post_id)
    if(!post)
      return

    post.current_score = score
    Post.update_vote(post_id)
  },

  set_vote_stars: function(id_prefix, score) {
    for (var this_score=-5; this_score <= 5; ++this_score) {
      var text = $(id_prefix + "-" + this_score)
      if (!text)
        continue
      var on = text.down(".score-on")
      var off = text.down(".score-off")
      if (score != null && score >= this_score)
      {
        on.addClassName("score-visible")
        off.removeClassName("score-visible")
      }
      else
      {
        on.removeClassName("score-visible")
        off.addClassName("score-visible")
      }
    }
  },

  update_vote: function(post_id) {
    var post = Post.posts.get(post_id)
    Post.set_vote_stars("score-" + post_id, post.current_score)
  },

  vote: function(score, id, options) {
    notice('Voting for post #' + id + '...');
    var post = Post.posts.get(id)
    old_score = post.current_score
    post.current_score = score
    Post.update_vote(id)

    options["id"] = id
    options["score"] = score
    
    new Ajax.Request("/post/vote.json", {
      parameters: options,

      onComplete: function(resp) {
        var resp = resp.responseJSON

        if (resp.success) {
          notice("Vote saved for post #" + id);
          $("post-score-" + resp.post_id).update(resp.score)
        } else {
          notice("Error: " + resp.reason)
          post.current_score = old_score
          Post.update_vote(id)
        }
      }
    })
  },

  flag: function(id) {
    var reason = prompt("Why should this post be flagged for deletion?")

    if (!reason) {
      return false
    }
  
    new Ajax.Request("/post/flag.json", {
      parameters: {
        "id": id,
        "reason": reason
      },
    
      onComplete: function(req) {
        notice("Post was flagged for deletion")
        $("p" + id).down("img").addClassName("flagged")
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

  register: function(post) {
    post.tags = post.tags.match(/\S+/g)
    post.match_tags = post.tags.clone()
    post.match_tags.push("rating:" + post.rating.charAt(0))
    post.match_tags.push("status:" + post.status)
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
      var thumb = $("p" + pair.key)
      if (!thumb) return
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
      if (Post.blacklist_options.replace)
        thumb.src = bld ? "/preview/blacklisted.png" : post.preview_url
      else
        thumb.show(!bld)
    })

    if (Post.countText)
      Post.countText.textContent = count
    return count
  },

  init_blacklisted: function(options) {
    Post.blacklist_options = Object.extend({replace:false}, options);  
    var bl_entries = Cookie.raw_get("blacklisted_tags").split(/\&/)
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
  
    var blacklist_count = $("blacklist-count")
    if (blacklist_count)
      Post.countText = blacklist_count.appendChild(document.createTextNode(""));

    var sidebar = $("blacklisted-sidebar")
    if (!Post.apply_blacklists()) {
      if (sidebar) sidebar.hide()
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
