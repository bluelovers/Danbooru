Post = {
  posts: new Hash(),

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

  hide_blacklisted: function() {
    var blacklist = Cookie.get("blacklisted_tags").replace(/rating:questionable/, "rating:q").replace(/rating:explicit/, "rating:e").replace(/rating:safe/, "rating:s").match(/\S+/g)
  
    if (blacklist == null) {
      return
    }
  
    this.posts.each(function(pair) {
      if (pair.value.tags.intersect(blacklist).size() > 0) {
        if ($("p" + pair.key)) {
          $("p" + pair.key).hide()
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
  }
}