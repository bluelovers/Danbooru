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

function loadMode() {
  if (readCookie("tag-script") != "") {
    var hash = eval("(" + readCookie("tag-script") + ")")

    for (i in hash) {
      var o = document.createElement("option")
      o.value = "tag-script-" + i
      o.innerHTML = "Script: " + i
      $("mode").appendChild(o)
    }
  }

  $("mode").value = readCookie("mode") || "view"
  changeMode()
}

function addFavorite(post_id) {
  notice('Adding post #' + post_id)
  new Ajax.Request('/api/add_favorite/'+post_id, {
    asynchronous: true,
    method: 'post',
    onComplete: function(req) {
      if (req.status == 409) {
        notice("Post #" + post_id + " already in your favorites")
      } else if (req.status == 500) {
        notice("You are not logged in")
      } else {
        notice("Post #" + post_id + " added to favorites")
      }
    }
  })
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

function tagScriptCheckFirstTime() {
  if (readCookie("tag-script") == "") {
    $("mode").value = "view"
    createCookie("tag-script", $H({}).toJSON())
  }
}

function tagScriptUpdate(name, script) {
  var hash = eval("(" + readCookie("tag-script") + ")")
  if (script == null) {
    delete hash[name]
  } else {
    hash[name] = script
  }

  createCookie("tag-script", $H(hash).toJSON())
}


function changeMode() {
  var s = $F("mode")
  createCookie("mode", s, 7)

  if (s == "view") {
    document.body.style.background = "white"
  } else if (s == "edit") {
    document.body.style.background = "#FAF"
    document.body.style.background = "#3A3"
  } else if (s == "fav") {
    document.body.style.background = "#FFA"
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
  } else if (s == "new-tag-script") {
    tagScriptCheckFirstTime()

    var name = prompt("Enter a name for this tag script")

    if (name == null) {
      return
    }

    var script = prompt("Enter the tag script")
    tagScriptUpdate(name, script)
    var c = document.createElement("option")
    c.value = "tag-script-" + name
    c.innerHTML = "Script: " + name
    $("mode").appendChild(c)
    $("mode").value = "view"
    createCookie("mode", "view", 7)
    document.body.style.background = "#FFF"
  } else if (s == "delete-tag-script") {
    var name = prompt("Enter the script's name")

    tagScriptUpdate(name, null)
    $("mode").value = "view"
    createCookie("mode", "view")
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
    return false
  } else if (s.value == "edit") {
    var post = posts[post_id]
    var newTags = prompt('Change tags', post.tags.join(" "))

    if (!newTags) {
      return false
    }

    notice('Changing post #' + post_id + '...')

    newTags = newTags.split(/ /g).map(function(i) {return encodeURIComponent(i)}).sort()

    new Ajax.Request('/api/change_post', {
      asynchronous: true,
      method: 'post',
      parameters: 'id='+post_id+'&tags='+newTags.join(' '),
      onComplete: function(req) {
        notice('Tags changed for post #' + post_id)
      }
    })

    return false
  } else if (s.value == 'vote-down') {
    vote(-1, post_id)
    return false
  } else if (s.value == 'vote-up') {
    vote(1, post_id)
    return false
  } else if (s.value == 'lock-rating') {
    notice("Locking post #" + post_id + "...")
    new Ajax.Request("/api/lock_post", {
      asynchronous: true,
      method: "post",
      parameters: "id=" + post_id + "&rating=1",
      onComplete: function(r) {
        notice("Post #" + post_id + " locked")
      }
    })
    return false
  } else if (s.value == 'lock-note') {
    notice("Locking post #" + post_id + "...")
    new Ajax.Request("/api/lock_post", {
      asynchronous: true,
      method: "post",
      parameters: "id=" + post_id + "&note=1",
      onComplete: function(r) {
        notice("Post #" + post_id + " locked")
      }
    })
    return false
  } else if (s.value == 'delete') {
    deletePost(post_id)
    return false
  } else if (s.value.match(/^tag-script-/)) {
    var script = eval("(" + readCookie("tag-script") + ")")[s.value.substr(11,100)]
    var commands = tagScriptParse(script)
    commands.each(function(x) {
      posts[post_id].tags = tagScriptProcess(posts[post_id].tags, x)
    })

    notice('Changing post #' + post_id + '...')

    var newTags = posts[post_id].tags.map(function(i) {return encodeURIComponent(i)}).sort()

    new Ajax.Request('/api/change_post', {
      asynchronous: true,
      method: 'post',
      parameters: 'id='+post_id+'&tags='+newTags.join(' '),
      onComplete: function(req) {
        notice('Tags changed for post #' + post_id)
      }
    })

    return false
  }
}

function toggleTag(link, tag_field) {
  var input = $(tag_field)
  var tags = input.value.split(" ").select(function(i) {return i.length > 0})
  var tag = link.innerHTML

  if (tags.include(tag)) {
    input.value = tags.without(tag).join(" ") + " "
  } else {
    input.value = tags.concat([tag]).join(" ") + " "
  }

  if (link.style.backgroundColor == "rgb(0, 111, 250)") {
    link.style.backgroundColor = "rgb(255, 255, 255)"
    link.style.color = "rgb(0, 111, 250)"
  } else {
    link.style.backgroundColor = "rgb(0, 111, 250)"
    link.style.color = "rgb(255, 255, 255)"
  }

  return false
}

function markcom(id) {
  notice("Marking comment #" + id + " as spam...")
  new Ajax.Request("/comment/mark_as_spam/" + id + ".js", {
    asynchronous: true,
    method: "post",
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
      } else {
        notice("Error: " + resp["reason"]);
      }
    }
  })
}

function injectTagsHelper(tags) {
  var html = ""
  var tag_field = "post_tags"
  var current = $F(tag_field).split(" ")

  tags.split(" ").uniq().sort().each(function(tag) {
    html += '<a href="/post/index?tags=' + encodeURIComponent(tag) + '" onclick="toggleTag(this, \'' + tag_field + '\'); return false"'

    if (current.include(tag)) {
      html += ' style="background: rgb(0, 111, 250); color: rgb(255, 255, 255)"'
    }

    html += '>' + tag + '</a> '
  })

  return html
}

function injectTags(related, dest) {
  if (dest != null) {
    $(dest).innerHTML = injectTagsHelper(related)
  } else if (related) {
    $('related').innerHTML = injectTagsHelper(related)
  }

  if (readCookie("recent_tags").length > 0) {
    $('recent').innerHTML = injectTagsHelper(readCookie("recent_tags").cgiUnescape())
  }
}

function getTextSelection(field) {
  var text = field.value

  if (field.selectionStart) {
    if (field.selectionStart < field.textLength) {
      var start = field.selectionStart
      var stop = field.selectionStart

      while (field.value[start] != " " && start > 0) {
        start -= 1
      }

      while (field.value[stop] != " " && stop < field.textLength) {
        stop += 1
      }

      text = field.value.substr(start, (stop - start))
    }
  }

  return text
}

function romanize(tag_field) {
  $('related').innerHTML = '<em>Fetching...</em>'
  var tag_field = $(tag_field)
  var tags = getTextSelection(tag_field)

  new Ajax.Request('/tag/romanize', {
    method: 'get',
    parameters: 'tags=' + tags,
    onComplete: function(res) {
      $('related').innerHTML = res.responseText
    }
  })
}

function findRelTags(tag_field, tag_type) {
  $('related').innerHTML = '<em>Fetching...</em>'
  var tag_field = $(tag_field)
  var tags = getTextSelection(tag_field)
  var tag_type_param = ""

  if (tag_type != null) {
    tag_type_param = "&type=" + tag_type
  }

  new Ajax.Request('/tag/related.js', {
    method: 'get',
    onComplete:function(req) {
      var resp = eval("(" + req.responseText + ")").map(function(x) {return x[0]}).join(" ")
      $('related').innerHTML = injectTagsHelper(resp)
    },
    parameters:'tags=' + tags + tag_type_param
  })
}

function findArtist() {
  $('related').innerHTML = '<em>Fetching...</em>'
  new Ajax.Request('/artist/index.js', {
    method: 'get',
    onComplete: function(req) {
      var resp = eval("(" + req.responseText + ")")
      $('related').innerHTML = injectTagsHelper(resp.map(function(x) {return x["name"]}).join(" "))
    },
    parameters:'name='+$F('post_source')
  })
}

function deletePost(post_id) {
  new Ajax.Request('/post/destroy', {
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
}

function toggleImageResize() {
    var img = $("image");

    if ((img.full_size == 1) || (img.full_size == null)) {
        img.full_size = 0;
        img.original_width = img.width;
        img.original_height = img.height;
        var client_width = $("right-col").clientWidth - 50;
        var client_height = $("right-col").clientHeight;

        if (img.width > client_width) {
            var ratio = client_width / img.width;
            img.width = img.width * ratio;
            img.height = img.height * ratio;
        }
    } else {
        img.full_size = 1;
        img.width = img.original_width;
        img.height = img.original_height;
    }
}
