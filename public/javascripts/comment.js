Comment = {
  flag: function(id) {
    notice("Flagging comment for deletion...")

    new Ajax.Request("/comment/mark_as_spam.json", {
      parameters: {
        "id": id,
        "comment[is_spam]": 1
      },
      onComplete: function(resp) {
        var resp = resp.responseJSON

        if (resp.success) {
          notice("Comment flagged for deletion");
        } else {
          notice("Error: " + resp.reason);
        }
      }
    })
  },
  
  quote: function(id) {
    new Ajax.Request("/comment/show.json", {
      method: "get",
      parameters: {
        "id": id
      },
      onSuccess: function(resp) {
        var resp = resp.responseJSON
        var stripped_body = resp.body.replace(/\[quote\](?:.|\n|\r)+?\[\/quote\](?:\r\n|\r|\n)*/gm, "")
        var body = '[quote]' + resp.creator + ' said:\n' + stripped_body + '\n[/quote]\n\n'
        $('reply-' + resp.post_id).show()
				if ($('respond-link-' + resp.post_id)) {
        	$('respond-link-' + resp.post_id).hide()
				}
        $('reply-text-' + resp.post_id).value += body
      },
      onFailure: function(req) {
        notice("Error quoting comment")
      }
    })
  },
  destroy: function(id) {
    if (!confirm("Are you sure you want to delete this comment?") ) {
      return;
    }

    new Ajax.Request("/comment/destroy.json", {
      parameters: {
        "id": id
      },
      onSuccess: function(resp) {
        document.location.reload()
      },
      onFailure: function(resp) {
        var resp = resp.responseJSON
        notice("Error deleting comment: " + resp.reason)
      }
    })
  }
}
