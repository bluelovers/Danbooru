Favorite = {}

Favorite.create = function(post_id) {
  notice('Adding post #' + post_id)

  new Ajax.Request('/favorite/create.js', {
    asynchronous: true,
    method: 'post',
		postBody: 'id='+post_id,
    onComplete: function(req) {
      var resp = eval("(" + req.responseText + ")")

      if (req.status == 409) {
        notice("Post #" + post_id + " already in your favorites")
      } else if (req.status == 500) {
        notice("You are not logged in")
      } else {
        notice("Post #" + post_id + " added to favorites")
        
        if ($("favorited-by")) {
          $("favorited-by").innerHTML = resp.favorited
        }
        
        if ($("post-score-" + resp.post_id)) {
          $("post-score-" + resp.post_id).innerHTML = resp.score
        }
      }
    }
  })
}

Favorite.destroy = function(post_id) {
  notice('Removing post #' + post_id)

  new Ajax.Request('/favorite/destroy.js', {
    asynchronous: true,
    method: 'post',
		postBody: 'id='+post_id,
    onComplete: function(res) {
      var resp = eval("(" + res.responseText + ")")

      notice("Post #" + post_id + " removed from your favorites")
        
      if ($("favorited-by")) {
        $("favorited-by").innerHTML = resp.favorited
      }
        
      if ($("post-score-" + resp.post_id)) {
        $("post-score-" + resp.post_id).innerHTML = resp.score
      }
    }
  })
}
