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
