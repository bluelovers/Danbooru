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

function loadMode() {
	if (readCookie("add_tags").length > 0) {
		readCookie("add_tags").split(/,/g).each(function(i) {
			var c = document.createElement("option")
			c.value = "add=" + i
			c.innerHTML = "Add tag: " + i
			$("mode").appendChild(c)
		})
	}

	if (readCookie("remove_tags").length > 0) {
		readCookie("remove_tags").split(/,/g).each(function(i) {
			var c = document.createElement("option")
			c.value = "remove=" + i
			c.innerHTML = "Remove tag: " + i
			$("mode").appendChild(c)
		})
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

function changeMode() {
	var s = $F("mode")
	createCookie("mode", s, 7)

	if (s == "view") {
		document.body.style.background = "white"
	} else if (s == "edit") {
		document.body.style.background = "#FAF"
	} else if (s == "rating-explicit") {
		document.body.style.background = "#A33"
	} else if (s == "rating-quest") {
		document.body.style.background = "#333"
	} else if (s == "rating-safe") {
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
	} else if (s == "new-tag-script") {
		if (readCookie("tag-script-redirected") == "") {
			writeCookie("tag-script-redirected", "1")
			location.href = "/wiki/view?title=Help%3ATag_Scripts"
			return
		}

		var name = prompt("Enter a name for this tag script")
		var tag = prompt("Enter the tag script")

		if (readCookie("tag-script") == "") {
			writeCookie("tag-script", {}.toJSON())
		}

		var hash = eval("(" + readCookie("tag-script") + ")")
		hash[name] = tag
		writeCookie("tag-script", hash.toJSON())

		var c = document.createElement("option")
		c.value = "script=" + name
		c.innerHTML = "script: " + name
		$("mode").appendChild(c)
		$("mode").value = "view"
		createCookie("mode", "view", 7)
		document.body.style.background = "#FFF"
	} else if (s == "clear-tag-script") {
		createCookie("mode", "view", 7)
		$("mode").value = "view"
		eraseCookie("tag-script")
	} else if (s.match(/^script=/)) {
		document.body.style.background = "#600"
	} else {
		document.body.style.background = "#AFA"
	}
}

function createCookie(name, value, days) {
	if (days) {
		var date = new Date()
		date.setTime(date.getTime() + (days * 24 * 60 * 60 * 1000))
		var expires = "; expires=" + date.toGMTString()
	} else {
		var expires = ""
	}

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
	} else if (s.value == 'rating-explicit' || s.value == 'rating-safe' || s.value == 'rating-quest') {
		notice('Changing post #' + post_id + '...')
		var rat = ""
		if (s.value == 'rating-explicit') {
			rat = "explicit"
		} else if (s.value == "rating-safe") {
			rat = "safe"
		} else {
			rat = "questionable"
		}

		new Ajax.Request("/api/change_post", {
			asynchronous: true,
			method: "post",
			parameters: "id=" + post_id + "&rating=" + rat,
			onComplete: function(req) {
				if (req.status >= 200 && req.status < 300) {
					notice("Rating changed for post #" + post_id)
				} else {
					notice("Failed: " + req.responseText)
				}
			}
		})

		return false
	} else if (s.value.match(/^add=/)) {
		var tags = s.value.match(/^add=(.+)/)[1] + " " + posts[post_id].tags.join(" ")

		notice('Changing post #' + post_id + '...')

		var newTags = tags.split(/ /g).map(function(i) {return encodeURIComponent(i)}).sort()

		new Ajax.Request('/api/change_post', {
			asynchronous: true,
			method: 'post',
			parameters: 'id='+post_id+'&tags='+newTags.join(' '),
			onComplete: function(req) {
				notice('Tags changed for post #' + post_id)
			}
		})

		return false
	} else if (s.value.match(/^remove=/)) {
		var tags = posts[post_id].tags.without(s.value.match(/^remove=(.+)/)[1]).join(" ")

		notice('Changing post #' + post_id + '...')

		var newTags = tags.split(/ /g).map(function(i) {return encodeURIComponent(i)}).sort()

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
	notice("Marking comment #" + id + " as noise...")
	new Ajax.Request("/api/mark_comment/" + id, {
		asynchronous: true,
		method: "post",
		onComplete: function(req) {
			if (req.status == 200) {
				notice("Comment #" + id + " marked as noise");
			} else {
				notice("Error: " + req.responseText);
			}
		}
	})
}

function vote(method, id) {
	notice('Voting for post #' + id + '...');
	var action = ""

	new Ajax.Request("/api/score_post", {
		asynchronous: true,
		method: "post",
		parameters: "id=" + id + "&score=" + method,
		onComplete: function(req) {
			if (req.status == 200) {
				notice("Vote saved for post #" + id);
			} else {
				notice("Error: " + req.responseText);
			}
		}
	})
}

function injectTagsHelper(tags) {
	var html = ""
	var tag_field = "post_tags"
	var current = $F(tag_field).split(" ")

	tags.cgiUnescape().split(" ").uniq().sort().each(function(tag) {
		html += '<a href="/post/list?tags=' + encodeURIComponent(tag) + '" onclick="toggleTag(this, \'' + tag_field + '\'); return false"'

		if (current.include(tag)) {
			html += ' style="background: rgb(0, 111, 250); color: rgb(255, 255, 255)"'
		}

		html += '>' + tag + '</a> '
	})

	return html
}

function injectTags(related) {
	if (related) {
		$('related').innerHTML = injectTagsHelper(related)
	}

	if (readCookie("my_tags").length > 0) {
		$('mytags').innerHTML = injectTagsHelper(readCookie("my_tags"))
	}

	if (readCookie("recent_tags").length > 0) {
		$('recent').innerHTML = injectTagsHelper(readCookie("recent_tags"))
	}
}

function filterComments(post_id, comment_size) {
	var cignored = []
	var j = comment_size - 5

	for (i in posts[post_id].comments) {
		var hidden = false

		if (posts[post_id].comments[i].score < cthreshold) {
			hidden = true
		}

		if (!hidden && users.include(posts[post_id].comments[i].user)) {
			hidden = true
		}

		if (hidden) {
			j -= 1
			Element.hide('c' + i)
			Element.addClassName('c' + i, 'ignored-comment')
			cignored.push('c' + i)
		} else if (j-- > 0) {
			Element.hide('c' + i)
			Element.addClassName('c' + i, 'hidden-comment')
			cignored.push('c' + i)
		}
	}	

	if (cignored.length > 0) {
		$('ci' + post_id).innerHTML = cignored.length + ' hidden'
		var cmd = "(function() {"
		cignored.each(function(x) {
			cmd += "Element.toggle('" + x + "'); "
		})
		cmd += "return false})"
		$('ci' + post_id).onclick = eval(cmd)
	}
}

function filterPosts(posts) {
	var tags = readCookie("tag_blacklist").split(/[, ]+/g)
	var users = readCookie("user_blacklist").split(/[, ]+/g)
	var threshold = parseInt(readCookie("post_threshold")) || 0
	var ignored = []

	for (i in posts)  {
		var hidden = false

		if (posts[i].score < threshold) {
			hidden = true
		}

		if (!hidden && users.include(posts[i].user)) {
			hidden = true
		}

		if (!hidden) {
			if (tags.include(posts[i].rating.toLowerCase())) {
				hidden = true
			}
		}

		if (!hidden) {
			tags.each(function(j) {
				if (posts[i].tags.include(j)) {
					hidden = true
				}
			})
		}

		if (hidden) {
			Element.addClassName('p' + i, 'ignored-post')
			Element.hide('p' + i)
			ignored.push('p' + i)
		}
	}

	if (ignored.length > 0) {
		var cmd = ""
		ignored.each(function(x) {
			cmd += "Element.toggle('" + x + "'); "
		})
		cmd += "return false"
		document.writeln('<div style="float: left; clear: both; text-align: center;"><a href="#" onclick="' + cmd + '">' + ignored.length + ' post' + (ignored.length == 1 ? '' : 's') + ' ignored</a></div>')
	}
}
