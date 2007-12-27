PostModeMenu = {
  init: function() {
    if (Cookie.get("mode") == "") {
      Cookie.put("mode", "view")
      $("mode").value = "view"
    } else {
      $("mode").value = Cookie.get("mode")
    }
  
    this.change()  
  },

  change: function() {
    var s = $F("mode")
    Cookie.put("mode", s, 7)

    if (s == "view") {
      document.body.setStyle({background: "#FFF"})
    } else if (s == "edit") {
      document.body.setStyle({background: "#3A3"})
    } else if (s == "fav") {
      document.body.setStyle({background: "#FFA"})
    } else if (s == "rating-q") {
      document.body.setStyle({background: "#AAA"})
    } else if (s == "rating-s") {
      document.body.setStyle({background: "#6F6"})
    } else if (s == "rating-e") {
      document.body.setStyle({background: "#F66"})
    } else if (s == "vote-down") {
      document.body.setStyle({background: "#FAA"})
    } else if (s == "vote-up") {
      document.body.setStyle({background: "#AFA"})
    } else if (s == "lock-rating") {
      document.body.setStyle({background: "#AA3"})
    } else if (s == "lock-note") {
      document.body.setStyle({background: "#3AA"})
    } else if (s == "flag") {
      document.body.setStyle({background: "#F66"})
  	} else if (s == "add-to-pool") {
  		document.body.setStyle({background: "#26A"})
  	} else if (s == "apply-tag-script") {
  		document.body.setStyle({background: "#A3A"})
    } else if (s == "edit-tag-script") {
  	  document.body.setStyle({background: "white"})
	  
  		var script = prompt("Enter a tag script")
		
  		if (script) {
  			Cookie.put("tag-script", script)
  		}
		
  		Cookie.put("mode", "view", 7)
  		$("mode").value = "view"
    } else {
      document.body.setStyle({background: "#AFA"})
    }
  },

  click: function(post_id) {
    var s = $("mode")

    if (s.value == "view") {
      return true
    } else if (s.value == "fav") {
      Favorite.create(post_id)
    } else if (s.value == "edit") {
      var post = Post.posts.get(post_id)
      $("id").value = post_id
      $("post_tags").value = post.tags.join(" ")
      $("quick-edit").show()
      return false
    } else if (s.value == 'vote-down') {
      Post.vote(-1, post_id)
    } else if (s.value == 'vote-up') {
      Post.vote(1, post_id)
    } else if (s.value == 'rating-q') {
      Post.update(post_id, {"post[rating]": "questionable"})
    } else if (s.value == 'rating-s') {
      Post.update(post_id, {"post[rating]": "safe"})
    } else if (s.value == 'rating-e') {
      Post.update(post_id, {"post[rating]": "explicit"})
    } else if (s.value == 'lock-rating') {
      Post.update(post_id, {"post[is_rating_locked]": "1"})
    } else if (s.value == 'lock-note') {
      Post.update(post_id, {"post[is_note_locked]": "1"})
    } else if (s.value == 'flag') {
      Post.flag(post_id)
  	} else if (s.value == 'add-to-pool') {
  		Pool.add_post(post_id, 0)
  	} else if (s.value == "apply-tag-script") {
      var tag_script = Cookie.get("tag-script")
      var commands = TagScript.parse(tag_script)
      var post = Post.posts.get(post_id)

      commands.each(function(x) {
        post.tags = TagScript.process(post.tags, x)
      })

      Post.update(post_id, {"post[tags]": post.tags.join(" ")})
    }

    return false
  }
}

TagScript = {
  parse: function(script) {
    return script.match(/\[.+?\]|\S+/g)
  },

  test: function(tags, predicate) {
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
  },

  process: function(tags, command) {
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
}