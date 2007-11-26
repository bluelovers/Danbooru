Dmail = {}

Dmail.respond = function(to) {
  $("dmail_to_name").value = to
  $("dmail_body").value = "[quote]You said:\n" + $("dmail_body").value.replace(/\[quote\](?:.|\n)+?\[\/quote\]\n*/gm, "") + "[/quote]\n\n"
  $("response").show()
}

Dmail.expand = function(parent_id, id) {
  notice("Fetching previous messages...")
  new Ajax.Updater('previous-messages', '/dmail/show_previous_messages?id=' + id + '&parent_id=' + parent_id, {
    method: 'get',
    onComplete: function() {
      $('previous-messages').show()
      notice("Previous messages loaded")
    }
  })
}
