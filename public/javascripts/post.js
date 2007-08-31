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
