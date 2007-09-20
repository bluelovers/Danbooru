Post = {}

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
