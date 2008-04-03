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
          $("p" + post_id).down("a/img").removeClassName("pending")
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
        $("p" + id).down("a/img").addClassName("flagged")
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

  register: function(post_id, tags, rating) {
    tags = tags + " rating:" + rating[0]
    this.posts.set(post_id, {"tags": tags.match(/\S+/g)})
  },

  blacklist_set: null,

  is_blacklisted: function(post_id) {
    if (Post.blacklist_set == null) {
      var blacklists = Cookie.raw_get("blacklisted_tags").split(/\&/)
      Post.blacklist_set = []

      blacklists.each(function(val) {
        s = Cookie.unescape(val)
        s = s.replace(/rating:questionable/, "rating:q").replace(/rating:explicit/, "rating:e").replace(/rating:safe/, "rating:s")
        Post.blacklist_set.push(s.match(/\S+/g) || [])
      })
    }

    var post = this.posts.get(post_id)
    var ret = false
    Post.blacklist_set.each(function(b) {
      if (b.size() && post.tags.intersect(b).size() == b.size())
        ret = true
    })
    return ret
  },

  hide_blacklisted: function() {
    this.posts.each(function(pair) {
      if (Post.is_blacklisted(pair.key)) {
        var post = $("p" + pair.key)
        if (post) {
          post.hide()
        }
      }
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
