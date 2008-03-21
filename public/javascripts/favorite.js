Favorite = {
  link_to_users: function(users) {
    var split_users = users.split(/,/)
    
    if ((split_users.size() == 1) && (split_users[0] == "")) {
      return "no one"
    } else {
      return split_users.map(function(x) {return '<a href="/post/index?tags=fav%3A' + encodeURIComponent(x) + '+order%3Afav">' + x + '</a>'}).join(", ")
    }
  },
  
  create: function(post_id) {
    notice('Adding post #' + post_id)

    new Ajax.Request('/favorite/create.json', {
      parameters: {
        id: post_id
      },
      onComplete: function(resp) {
        var resp = resp.responseJSON

        if (resp.success) {
          notice("Post #" + post_id + " added to favorites")
        
          if ($("favorited-by")) {
            $("favorited-by").update(Favorite.link_to_users(resp.favorited))
          }
          
          if ($("add-to-favs")) {
            $("add-to-favs").hide()
            $("remove-from-favs").show()
          }
        
          if ($("post-score-" + resp.post_id)) {
            $("post-score-" + resp.post_id).update(resp.score)
          }          
        } else {
          notice("Error: " + resp.reason)
        }
      }
    })
  },

  destroy: function(post_id) {
    notice('Removing post #' + post_id)

    new Ajax.Request('/favorite/destroy.json', {
      parameters: {
        id: post_id
      },
      onComplete: function(resp) {
        var resp = resp.responseJSON
        notice("Post #" + post_id + " removed from your favorites")
        
        if ($("favorited-by")) {
          $("favorited-by").update(Favorite.link_to_users(resp.favorited))
        }
        
        if ($("add-to-favs")) {
          $("add-to-favs").show()
          $("remove-from-favs").hide()
        }
        
        if ($("post-score-" + resp.post_id)) {
          $("post-score-" + resp.post_id).update(resp.score)
        }
        
        if ($("p" + resp.post_id)) {
          $("p" + resp.post_id).hide()
        }
      }
    })
  }
}
