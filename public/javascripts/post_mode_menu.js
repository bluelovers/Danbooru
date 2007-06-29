function loadMode() {
  if (readCookie("tag-scripts") != "") {
    var tag_scripts = eval(readCookie("tag-scripts"))

    for (i=0; i<tag_scripts.length; ++i) {
      var o = document.createElement("option")
      o.value = "tag-script-" + tag_scripts[i][0]
      o.text = "Script: " + tag_scripts[i][1]
      $("mode").appendChild(o)
    }
  }

  $("mode").value = readCookie("mode")
  changeMode()
}

function changeMode() {
  var s = $F("mode")
  createCookie("mode", s, 7)

  if (s == "view") {
    document.body.style.background = "white"
  } else if (s == "edit") {
    document.body.style.background = "#3A3"
  } else if (s == "fav") {
    document.body.style.background = "#FFA"
  } else if (s == "rating-q") {
    document.body.style.background = "#AAA"
  } else if (s == "rating-s") {
    document.body.style.background = "#6F6"
  } else if (s == "rating-e") {
    document.body.style.background = "#F66"
  } else if (s == "vote-down") {
    document.body.style.background = "#FAA"
  } else if (s == "vote-up") {
    document.body.style.background = "#AFA"
  } else if (s == "lock-rating") {
    document.body.style.background = "#AA3"
  } else if (s == "lock-note") {
    document.body.style.background = "#3AA"
  } else if (s == "delete") {
    document.body.style.background = "#F00"
  } else if (s == "edit-tag-scripts") {
    createCookie("mode", "view")
    location.href = "/post/edit_tag_scripts?url=" + encodeURIComponent(location.href)
  } else {
    document.body.style.background = "#AFA"
  }
}

function postClick(post_id) {
  var s = $("mode")

  if (s.value == "view") {
    return true
  } else if (s.value == "fav") {
    addFavorite(post_id)
  } else if (s.value == "edit") {
    var post = posts[post_id]
    var newTags = prompt('Change tags', post.tags.join(" "))

    if (!newTags) {
      return false
    }

    notice('Changing post #' + post_id + '...')
    newTags = newTags.split(/ /g).map(function(i) {return encodeURIComponent(i)}).sort()
    new Ajax.Request('/post/update.js', {
      asynchronous: true,
      method: 'post',
      postBody: 'id='+post_id+'&post[tags]='+newTags.join(' '),
      onComplete: function(req) {
        notice('Tags changed for post #' + post_id)
      }
    })
  } else if (s.value == 'vote-down') {
    vote(-1, post_id)
  } else if (s.value == 'vote-up') {
    vote(1, post_id)
  } else if (s.value == 'rating-q') {
    notice("Rating post #" + post_id + "...")
    new Ajax.Request("/post/update.js", {
      asynchronous: true,
      method: "post",
      postBody: "id=" + post_id + "&post[rating]=questionable",
      onComplete: function(r) {
        notice("Post #" + post_id + " marked as questionable")
      }
    })
  } else if (s.value == 'rating-s') {
    notice("Rating post #" + post_id + "...")
    new Ajax.Request("/post/update.js", {
      asynchronous: true,
      method: "post",
      postBody: "id=" + post_id + "&post[rating]=safe",
      onComplete: function(r) {
        notice("Post #" + post_id + " marked as safe")
      }
    })
  } else if (s.value == 'rating-e') {
    notice("Rating post #" + post_id + "...")
    new Ajax.Request("/post/update.js", {
      asynchronous: true,
      method: "post",
      postBody: "id=" + post_id + "&post[rating]=explicit",
      onComplete: function(r) {
        notice("Post #" + post_id + " marked as explicit")
      }
    })
  } else if (s.value == 'lock-rating') {
    notice("Locking post #" + post_id + "...")
    new Ajax.Request("/post/update.js", {
      asynchronous: true,
      method: "post",
      postBody: "id=" + post_id + "&post[is_rating_locked]=1",
      onComplete: function(r) {
        notice("Post #" + post_id + " locked")
      }
    })
  } else if (s.value == 'lock-note') {
    notice("Locking post #" + post_id + "...")
    new Ajax.Request("/post/update.js", {
      asynchronous: true,
      method: "post",
      parameters: "id=" + post_id + "&post[is_note_locked]=1",
      onComplete: function(r) {
        notice("Post #" + post_id + " locked")
      }
    })
  } else if (s.value == 'delete') {
    new Ajax.Request('/post/destroy.js', {
      method: 'post',
      postBody: 'id=' + post_id,
      onComplete: function(res) {
        var resp = eval('(' + res.responseText + ')')
        if (resp['success'] == true) {
          notice('Post #' + post_id + ' deleted')
        } else {
          notice('Error: ' + resp['reason'])
        }
      }
    })
  } else if (s.value.match(/^tag-script-/)) {
    var tag_script = getTagScript(s.value.substr(11, 100))
    var commands = tagScriptParse(tag_script)

    commands.each(function(x) {
      posts[post_id].tags = tagScriptProcess(posts[post_id].tags, x)
    })

    notice('Changing post #' + post_id + '...')

    var newTags = posts[post_id].tags.map(function(i) {return encodeURIComponent(i)}).sort()

    new Ajax.Request('/post/update.js', {
      asynchronous: true,
      method: 'post',
      postBody: 'id='+post_id+'&post[tags]='+newTags.join(' '),
      onComplete: function(req) {
        notice('Tags changed for post #' + post_id)
      }
    })
  }

  return false
}

function getTagScript(id) {
  id = parseInt(id)
  if (readCookie("tag-scripts")) {
    var tag_scripts = eval(readCookie("tag-scripts"))
    for (i=0; i<tag_scripts.length; ++i) {
      if (tag_scripts[i][0] == id) {
        return tag_scripts[i][2]
      }
    }
  } else {
    return ""
  }
}

function tagScriptParse(script) {
  return script.match(/\[.+?\]|\S+/g)
}

function tagScriptTest(tags, predicate) {
  var split_pred = predicate.match(/\S+/g)
  var is_true = true

  split_pred.each(function(x) {
    if (x[0] == "-") {
      if (tags.include(x.substr(1, 100))) {
        is_true = false
        throw $break
      }
    } else {
      if (!tags.include(x)) {
        is_true = false
        throw $break
      }
    }
  })

  return is_true
}

function tagScriptProcess(tags, command) {
  if (command.match(/^\[if/)) {
    var match = command.match(/\[if\s*,\s*(.+?)\s*,\s*(.+?)\]/)
    if (tagScriptTest(tags, match[1])) {
      return tagScriptProcess(tags, match[2])
    } else {
      return tags
    }
  } else if (command == "[reset]") {
    return []
  } else if (command[0] == "-") {
    return tags.reject(function(x) {return x == command.substr(1, 100)})
  } else {
    tags.push(command)
    return tags
  }
}
