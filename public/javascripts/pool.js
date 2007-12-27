Pool = {
  add_post: function(post_id, pool_id) {
  	notice("Adding to pool...")

  	new Ajax.Request("/pool/add_post.js", {
  	  parameters: {
  	    "post_id": post_id,
  	    "pool_id": pool_id
  	  },
  		onComplete: function(resp) {
  		  var resp = resp.responseJSON
			
  			if (resp.success) {
  				notice("Post added to pool")
  			} else {
  				notice("Error: " + resp.reason)				
  			}
  		}
  	})
  },

  remove_post: function(post_id, pool_id) {
    if ($("del-mode") && $("del-mode").checked == true) {
      new Ajax.Request('/pool/remove_post.js', {
        parameters: {
          "post_id": post_id,
          "pool_id": pool_id
        },
        onComplete: function(resp) {
          var resp = resp.responseJSON
          
          notice("Post removed from pool")
          $("p" + resp.post_id).remove()
        }
      })

      return false
    } else {
      return true
    }
  }
}