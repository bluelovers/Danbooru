Object.extend(Array.prototype, {
  uniq: (function() {
    var temp = []
    for (i=0; i<this.length; ++i) {
      if (!temp.include(this[i])) {
        temp.push(this[i])
      }
    }
    return temp
  })
})

Object.extend(String.prototype, {
  cgiUnescape: function() {
    return decodeURIComponent(this.replace(/\+/g, " "))
  }
})

function notice(msg) {
  $('notice').innerHTML = msg
}

function createCookie(name, value, days) {
  if (days == null) {
    days = 365
  }

  var date = new Date()
  date.setTime(date.getTime() + (days * 24 * 60 * 60 * 1000))
  var expires = "; expires=" + date.toGMTString()
  document.cookie = name + "=" + value + expires + "; path=/"
}

function readCookie(name) {
  var nameEq = name + "="
  var ca = document.cookie.split(";")

  for (var i = 0; i < ca.length; ++i) {
    var c = ca[i]

    while (c.charAt(0) == " ") {
      c = c.substring(1, c.length)
    }

    if (c.indexOf(nameEq) == 0) {
      return c.substring(nameEq.length, c.length)
    }
  }

  return ""
}

function eraseCookie(name) {
  createCookie(name, "", -1)
}

function updatePost(post_id, params) {
  notice('Updating post')

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

function addFavorite(post_id) {
  notice('Adding post #' + post_id)
  new Ajax.Request('/user/add_favorite.js', {
    asynchronous: true,
    method: 'post',
		postBody: 'post_id='+post_id,
    onComplete: function(req) {
      var resp = eval("(" + req.responseText + ")")

      if (req.status == 409) {
        notice("Post #" + post_id + " already in your favorites")
      } else if (req.status == 500) {
        notice("You are not logged in")
      } else {
        notice("Post #" + post_id + " added to favorites")
        if ($("post-score-" + resp.post_id)) {
          $("post-score-" + resp.post_id).innerHTML = resp.score
        }
      }
    }
  })
}

function markcom(id) {
  notice("Marking comment #" + id + " as spam...")
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

function vote(score, id) {
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

