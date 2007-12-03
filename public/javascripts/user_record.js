UserRecord = {}

UserRecord.destroy = function(id) {
  notice('Deleting record #' + id)

  new Ajax.Request('/user_record/destroy.js', {
    asynchronous: true,
    method: 'post',
    postBody: 'id=' + id,
    onComplete: function(resp) {
      if (resp.status == 200) {
        notice("Record deleted")
      } else {
        notice("Access denied")
      }
    }
  })
}
