Comment = {}

Comment.flag = function(id) {
  notice("Flagging comment for deletion...")

  new Ajax.Request("/comment/mark_as_spam.js/", {
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

