Forum = {
  quote: function(id) {
    new Ajax.Request("/forum/show.js", {
      method: 'get',
      parameters: {
        "id": id
      },
      onSuccess: function(resp) {
        var resp = resp.responseJSON
        $('reply').show().scrollTo()
        var stripped_body = resp.body.replace(/\[quote\](?:.|\n)+?\[\/quote\]\n*/gm, "")
        $('forum_post_body').value += '[quote]' + resp.creator + ' said:\n' + stripped_body + '\n[/quote]\n\n'
      },
      onFailure: function(req) {
        notice("Error quoting forum post")
      }
    })
  }
}
