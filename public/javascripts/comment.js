Comment = {}

Comment.mark_as_spam = function(id) {
  notice("Marking comment as spam...")

  new Ajax.Request("/comment/mark_as_spam.js/", {
    asynchronous: true,
    method: "post",
    postBody: "id=" + id + "&comment[is_spam]=1",
    onComplete: function(req) {
      var resp = eval("(" + req.responseText + ")")
      if (resp["success"]) {
        notice("Comment #" + id + " marked as spam");
      } else {
        notice("Error: " + resp["reason"]);
      }
    }
  })
}

