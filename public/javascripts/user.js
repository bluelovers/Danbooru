User = {
  disable_samples: function() {
    new Ajax.Request("/user/update.json", {
      parameters: {
	"user[show_samples]": false
      },

      onComplete: function(resp) {
	var resp = resp.responseJSON

	if (resp.success) {
	  $("resized_notice").hide();
	  $("samples_disabled").show();
	  Post.highres();
	} else {
	  notice("Error: " + resp.reason)
	}
      }
    })
  },

  destroy: function(id) {
    notice("Deleting record #" + id)

    new Ajax.Request("/user_record/destroy.json", {
      parameters: {
        "id": id
      },
      onComplete: function(resp) {
        if (resp.status == 200) {
          notice("Record deleted")
        } else {
          notice("Access denied")
        }
      }
    })
  }
}
