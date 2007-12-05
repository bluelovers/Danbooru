Post = {}

Post.posts = {}

Post.update = function(post_id, params) {
  notice('Updating post #' + post_id)

  new Ajax.Request('/post/update.js', {
    asynchronous: true,
    method: 'post',
    postBody: 'id=' + post_id + '&' + params,
    onComplete: function(req) {
      var resp = eval("(" + req.responseText + ")")
      if (resp.success) {
        notice('Post updated')
      } else {
        notice('Error: ' + resp.reason)
      }
    }
  })
}

Post.vote = function(score, id) {
  notice('Voting for post #' + id + '...');

  new Ajax.Request("/post/vote.js", {
    asynchronous: true,
    method: "post",
    postBody: "id=" + id + "&score=" + score,
    onComplete: function(req) {
      resp = eval("(" + req.responseText + ")")
      if (resp["success"]) {
        notice("Vote saved for post #" + id);
        $("post-score-" + resp["post_id"]).innerHTML = resp["score"]
      } else {
        notice("Error: " + resp["reason"]);
      }
    }
  })
}

Post.flag = function(id) {
  var reason = prompt("Why should this post be flagged for deletion?")

  if (!reason) {
    return false
  }
  
  new Ajax.Request("/post/flag.js", {
    asynchronous: true,
    method: "post",
    postBody: "id=" + id + "&reason=" + escape(reason),
    onComplete: function(req) {
      notice("Post was flagged for deletion")
    }
  })
}

Post.submit_tags = function(form, e) {
  if (!e) {
    e = window.event
  }
  
  var form = $(form)
  
	if (e.keyCode == 13 || e.keyCode == 3) {
		if (!form.onsubmit || form.onsubmit()) {
			form.submit()
      Event.stop(e)
		}
	}
}

Post.register = function(post_id, tags, rating) {
  tags = tags + " rating:" + rating[0]
  this.posts[post_id] = {"tags": tags.match(/\S+/g)}
}

Post.hide_blacklisted = function() {
  var blacklist = Cookie.get("blacklisted_tags").match(/\S+/g)
  
  if (blacklist == null) {
    return
  }
  
  for (var id in this.posts) {
    for (var i=0; i< this.posts[id].tags.length; ++i) {
      if (blacklist.include(this.posts[id].tags[i])) {
        console.log("hiding %d", id)
        $("p" + id).hide()
        break
      }
    }
  }
}

Post.resize_image = function() {
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
