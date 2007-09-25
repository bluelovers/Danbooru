Forum = {}

Forum.quote = function(id) {
  new Ajax.Request("/forum/show/" + id + ".js", {
    asynchronous: true,
    onSuccess: function(req) {
      var resp = eval("(" + req.responseText + ")")
      $('reply').show()
      $('forum_post_body').value = '<quote>' + resp.creator + ' said:\n' + resp.body.replace(/<quote>(?:.|\n)+?<\/quote>\n*/gm, "") + '\n</quote>\n\n'
    },
    onFailure: function(req) {
      notice("Error quoting forum post")
    }
  })
}
