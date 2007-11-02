Comment = {}

Comment.flag = function(id) {
  notice("Flagging comment for deletion...")

  new Ajax.Request("/comment/mark_as_spam.js", {
    asynchronous: true,
    method: "post",
    postBody: "id=" + id + "&comment[is_spam]=1",
    onComplete: function(req) {
      var resp = eval("(" + req.responseText + ")")
      if (resp["success"]) {
        notice("Comment flagged for deletion");
      } else {
        notice("Error: " + resp["reason"]);
      }
    }
  })
}

Comment.quote = function(id) {
  new Ajax.Request("/comment/show/" + id + ".js", {
    asynchronous: true,
    onSuccess: function(req) {
      var resp = eval("(" + req.responseText + ")")
      $('reply-' + resp.post_id).show()
      $('reply-text-' + resp.post_id).value += '<quote>' + resp.creator + ' said:\n' + resp.body.replace(/<quote>(?:.|\n)+?<\/quote>\n*/gm, "") + '\n</quote>\n\n'
    },
    onFailure: function(req) {
      notice("Error quoting comment")
    }
  })
}
