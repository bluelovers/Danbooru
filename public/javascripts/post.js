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

  vote: function(score, id) {
    notice('Voting for post #' + id + '...');

    new Ajax.Request("/post/vote.json", {
      parameters: {
        "id": id,
        "score": score
      },
    
      onComplete: function(resp) {
        var resp = resp.responseJSON

        if (resp.success) {
          notice("Vote saved for post #" + id);
          $("post-score-" + resp.post_id).update(resp.score)
        } else {
          notice("Error: " + resp.reason)
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
    this.posts.set(post.id, post)
  },

  blacklist_set: null,

  is_blacklisted: function(post_id) {
    if (Post.blacklist_set == null) {
      var blacklists = Cookie.raw_get("blacklisted_tags").split(/\&/)
      Post.blacklist_set = []

      blacklists.each(function(val) {
        s = Cookie.unescape(val)
        s = s.replace(/rating:questionable/, "rating:q").replace(/rating:explicit/, "rating:e").replace(/rating:safe/, "rating:s")
        Post.blacklist_set.push({tags: s.match(/\S+/g) || [], disabled: false, hits: 0 })
      })
    }

    var post = this.posts.get(post_id)
    var ret = []
    Post.blacklist_set.each(function(b) {
      match_tags = post.tags.clone()
      match_tags.push("rating:" + post.rating.substr(0, 1))
      match_tags.push("status:" + post.status)
      if (b.tags.size() && match_tags.intersect(b.tags).size() == b.tags.size()) {
        ++b.hits
        if (!b.disabled) {
          ret.splice(ret.size(), 0, b)
        }
      }
    })
    if (ret.size() == 0)
      return null
    return ret
  },

  hide_blacklisted: function() {
    if(Post.blacklist_set) {
      Post.blacklist_set.each(function(b) {
        b.hits = 0
      })
    }

    var count = 0
    this.posts.each(function(pair) {
      var post = $("p" + pair.key)
      if (!post) {
        return
      }

      pair.value.blacklisted = Post.is_blacklisted(pair.key)

      if (pair.value.blacklisted) {
        post.hide()
        ++count
      } else {
        post.show()
      }
    })

    Post.countText.textContent = count
    return count
  },

  init_blacklisted: function() {
    Post.countText = $("blacklist-count").appendChild(document.createTextNode(""));

    var sidebar = $("blacklisted-sidebar")
    if (!Post.hide_blacklisted()) {
      sidebar.hide()
      return
    }
    sidebar.show()

    /* Keep focus from going to the item on click. */
    sidebar.observe("mousedown", function(event) { event.stop() })

    var list = $("blacklisted-list")
    Post.blacklist_set.each(function(b) {
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
        Post.hide_blacklisted()
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
