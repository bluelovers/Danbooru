function loadMode() {
  if (readCookie("mode") == "") {
    createCookie("mode", "view")
    $("mode").value = "view"
  } else {
    $("mode").value = readCookie("mode")
  }
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
  } else if (s == "flag") {
    document.body.style.background = "#F00"
	} else if (s == "apply-tag-script") {
		document.body.style.background = "#A3A"
  } else if (s == "edit-tag-script") {
	  document.body.style.background = "white"
		var script = prompt("Enter a tag script")
		if (script) {
			createCookie("tag-script", script)
		}
		
		createCookie("mode", "view", 7)
		$("mode").value = "view"
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

    newTags = newTags.split(/ /g).map(function(i) {return encodeURIComponent(i)}).sort()
    updatePost(post_id, 'post[tags]=' + newTags.join(' '))
  } else if (s.value == 'vote-down') {
    vote(-1, post_id)
  } else if (s.value == 'vote-up') {
    vote(1, post_id)
  } else if (s.value == 'rating-q') {
    updatePost(post_id, 'post[rating]=questionable')
  } else if (s.value == 'rating-s') {
    updatePost(post_id, 'post[rating]=safe')
  } else if (s.value == 'rating-e') {
    updatePost(post_id, 'post[rating]=explicit')
  } else if (s.value == 'lock-rating') {
    updatePost(post_id, 'post[is_rating_locked]=1')
  } else if (s.value == 'lock-note') {
    updatePost(post_id, 'post[is_note_locked]=1')
  } else if (s.value == 'flag') {
    updatePost(post_id, 'post[is_flagged]=1')
	} else if (s.value == "apply-tag-script") {
    var tag_script = readCookie("tag-script")
    var commands = tagScriptParse(tag_script)

    commands.each(function(x) {
      posts[post_id].tags = tagScriptProcess(posts[post_id].tags, x)
    })

    var newTags = posts[post_id].tags.map(function(i) {return encodeURIComponent(i)}).sort()
    updatePost(post_id, 'post[tags]=' + newTags.join(' '))
  }

  return false
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
    var match = command.match(/\[if\s+(.+?)\s*,\s*(.+?)\]/)
		console.log("test=%s result=%s", match[1], match[2])
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
