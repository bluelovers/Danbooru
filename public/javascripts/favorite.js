Favorite = {
  create: function(post_id) {
    notice('Adding post #' + post_id)

    new Ajax.Request('/favorite/create.json', {
      parameters: {
        id: post_id
      },
      onComplete: function(resp) {
        var resp = eval("(" + decodeURIComponent(resp.responseText) + ")")
        if (resp.success) {
          notice("Post #" + post_id + " added to favorites")
        
          if ($("favorited-by")) {
            $("favorited-by").update(resp.favorited)
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
        var resp = eval("(" + decodeURIComponent(resp.responseText) + ")")
        notice("Post #" + post_id + " removed from your favorites")
        
        if ($("favorited-by")) {
          $("favorited-by").update(resp.favorited)
        }
        
        if ($("add-to-favs")) {
          $("add-to-favs").show()
          $("remove-from-favs").hide()
        }
        
        if ($("post-score-" + resp.post_id)) {
          $("post-score-" + resp.post_id).update(resp.score)
        }
      }
    })
  }
}
