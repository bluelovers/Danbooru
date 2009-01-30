Favorite = {
  link_to_users: function(users) {
    var split_users = users.split(/,/)
    var html = ""
    
    if ((split_users.size() == 1) && (split_users[0] == "")) {
      return "no one"
    } else {
       html = split_users.slice(0, 6).map(function(x) {return '<a href="/post/index?tags=fav%3A' + encodeURIComponent(x) + '">' + x + '</a>'}).join(", ")
      
      if (split_users.size() > 6) {
        html += '<span id="remaining-favs" style="display: none;">' + split_users.slice(6, -1).map(function(x) {return '<a href="/user/show?name=' + encodeURIComponent(x) + '">' + x + '</a>'}).join(", ") + '</span> <span id="remaining-favs-link">(<a href="#" onclick="$(\'remaining-favs\').show(); $(\'remaining-favs-link\').hide(); return false;">' + (split_users.size() - 6) + ' more</a>)</span>'
      }
      
      return html
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
            $("favorited-by").update(Favorite.link_to_users(resp.favorited_users))
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
          $("favorited-by").update(Favorite.link_to_users(resp.favorited_users))
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
