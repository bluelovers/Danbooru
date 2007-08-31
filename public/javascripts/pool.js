Pool = {}

Pool.add_post = function(post_id, pool_id) {
	notice("Adding to pool...")

	new Ajax.Request("/pool/add_post.js", {
		asynchronous: true,
		method: "post",
		postBody: "post_id=" + post_id + "&pool_id=" + pool_id,
		onComplete: function(res) {
			var resp = eval("(" + res.responseText + ")")
			
			if (resp.success) {
				notice("Post added to pool")
			} else {
				notice("Error: " + resp.reason)				
			}
		}
	})
}

Pool.remove_post = function(post_id, pool_id) {
  if ($("del-mode") && $("del-mode").checked == true) {
    new Ajax.Request('/pool/remove_post.js', {
      asynchronous: true,
      method: 'post',
      postBody: 'post_id=' + post_id + "&pool_id=" + pool_id,
      onComplete: function(res) {
        notice("Post removed from pool")
        Element.remove('p' + res.getResponseHeader('X-Post-Id'))
      }
    })

    return false
  } else {
    return true
  }
}