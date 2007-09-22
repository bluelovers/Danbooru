PostModeMenu = {}

PostModeMenu.init = function() {
  if (Cookie.get("mode") == "") {
    Cookie.put("mode", "view")
    $("mode").value = "view"
  } else {
    $("mode").value = Cookie.get("mode")
  }
  
  PostModeMenu.change()  
}

PostModeMenu.change = function() {
  var s = $F("mode")
  Cookie.put("mode", s, 7)

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
	} else if (s == "add-to-pool") {
		document.body.style.background = "#26A"
	} else if (s == "apply-tag-script") {
		document.body.style.background = "#A3A"
  } else if (s == "edit-tag-script") {
	  document.body.style.background = "white"
		var script = prompt("Enter a tag script")
		if (script) {
			Cookie.put("tag-script", script)
		}
		
		Cookie.put("mode", "view", 7)
		$("mode").value = "view"
  } else {
    document.body.style.background = "#AFA"
  }
}

PostModeMenu.click = function(post_id) {
  var s = $("mode")

  if (s.value == "view") {
    return true
  } else if (s.value == "fav") {
    Favorite.create(post_id)
  } else if (s.value == "edit") {
    var post = posts[post_id]
    var newTags = prompt('Change tags', post.tags.join(" "))

    if (!newTags) {
      return false
    }

    newTags = newTags.split(/ /g).map(function(i) {return encodeURIComponent(i)}).sort()
    Post.update(post_id, 'post[tags]=' + newTags.join(' '))
  } else if (s.value == 'vote-down') {
    Post.vote(-1, post_id)
  } else if (s.value == 'vote-up') {
    Post.vote(1, post_id)
  } else if (s.value == 'rating-q') {
    Post.update(post_id, 'post[rating]=questionable')
  } else if (s.value == 'rating-s') {
    Post.update(post_id, 'post[rating]=safe')
  } else if (s.value == 'rating-e') {
    Post.update(post_id, 'post[rating]=explicit')
  } else if (s.value == 'lock-rating') {
    Post.update(post_id, 'post[is_rating_locked]=1')
  } else if (s.value == 'lock-note') {
    Post.update(post_id, 'post[is_note_locked]=1')
  } else if (s.value == 'flag') {
    Post.update(post_id, 'post[is_flagged]=1')
	} else if (s.value == 'add-to-pool') {
		Pool.add_post(post_id, 0)
	} else if (s.value == "apply-tag-script") {
    var tag_script = Cookie.get("tag-script")
    var commands = TagScript.parse(tag_script)

    commands.each(function(x) {
      posts[post_id].tags = TagScript.process(posts[post_id].tags, x)
    })

    var newTags = posts[post_id].tags.map(function(i) {return encodeURIComponent(i)}).sort()
    Post.update(post_id, 'post[tags]=' + newTags.join(' '))
  }

  return false
}

TagScript = {}

TagScript.parse = function(script) {
  return script.match(/\[.+?\]|\S+/g)
}

TagScript.test = function(tags, predicate) {
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

TagScript.process = function(tags, command) {
  if (command.match(/^\[if/)) {
    var match = command.match(/\[if\s+(.+?)\s*,\s*(.+?)\]/)
    if (TagScript.test(tags, match[1])) {
      return TagScript.process(tags, match[2])
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
