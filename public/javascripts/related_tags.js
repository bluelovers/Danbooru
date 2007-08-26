RelatedTags = {}

RelatedTags.user_tags = []

RelatedTags.recent_tags = []

RelatedTags.recent_search = {}

RelatedTags.init = function(user_tags, artist_url) {
  RelatedTags.user_tags = user_tags.match(/\S+/g)

  if (readCookie("recent_tags").length > 0) {
    RelatedTags.recent_tags = readCookie("recent_tags").cgiUnescape().match(/\S+/g).uniq().sort()
  }
  
  if ((artist_url != null) && (artist_url.match(/^http/))) {
    RelatedTags.find_artist($F("post_source"))
  } else {
    RelatedTags.build_all({})
  }
}

RelatedTags.toggle = function(link, field) {
  var field = $(field)
  var tags = field.value.match(/\S+/g) || []
  var tag = link.innerHTML

  if (tags.include(tag)) {
    field.value = tags.without(tag).join(" ") + " "
  } else {
    field.value = tags.concat([tag]).join(" ") + " "
  }

  RelatedTags.build_all(RelatedTags.recent_search)
  return

  if (link.style.backgroundColor == "rgb(0, 111, 250)") {
    link.style.backgroundColor = "rgb(255, 255, 255)"
    link.style.color = "rgb(0, 111, 250)"
  } else {
    link.style.backgroundColor = "rgb(0, 111, 250)"
    link.style.color = "rgb(255, 255, 255)"
  }

  return false
}

RelatedTags.build_html = function(key, tags) {
  if (tags.length == 0) {
    return ""
  }
  
  var html = ""
  var current = $F("post_tags").match(/\S+/g) || []

  html += '<h6><em>' + key + '</em></h6>'
  html += '<p>'
  
  for (i=0; i<tags.length; ++i) {
    var tag = tags[i]
    html += ('<a href="/post/index?tags=' + encodeURIComponent(tag) + '" onclick="RelatedTags.toggle(this, \'post_tags\'); return false"')
    
    if (current.include(tag)) {
      html += ' style="background: rgb(0, 111, 250); color: white;"'
    }
    
    html += '>' + tag + '</a> '
  }
  html += '</p>'

  return html
}

RelatedTags.build_all = function(tags) {
  RelatedTags.recent_search = tags
  
  var html = RelatedTags.build_html("My Tags", RelatedTags.user_tags) + RelatedTags.build_html("Recent Tags", RelatedTags.recent_tags)
  
  for (key in tags) {
    html += RelatedTags.build_html(key, tags[key])
  }
  
  $("related").innerHTML = html
}

RelatedTags.find = function(field, type) {
  $("related").innerHTML = "<em>Fetching...</em>"
  var field = $(field)
  var tags = field.value
  var type_param = ""
  
  if (type != null) {
    type_param = "&type=" + type
  }
  
  new Ajax.Request("/tag/related.js", {
    method: 'get',
    parameters: "tags=" + tags + type_param,
    onComplete: function(res) {
      var resp = eval("(" + res.responseText + ")")
      RelatedTags.build_all(RelatedTags.convert_related_js_response(resp))
    }
  })
}

RelatedTags.convert_related_js_response = function(resp) {
  var converted = {}
  
  for (k in resp) {
    var tags = resp[k].map(function(x) {return x[0]}).sort()
    converted[k] = tags
  }
  
  return converted
}

RelatedTags.find_artist = function(url) {
  if (url.match(/^http/)) {
    new Ajax.Request("/artist/index.js", {
      method: "get",
      parameters: "url=" + url,
      onComplete: function(res) {
        var resp = eval(res.responseText)
        RelatedTags.build_all({"Artist": resp.map(function(x) {return x.name})})
      }
    })
  }
}
