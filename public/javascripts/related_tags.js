RelatedTags = {
  uploaded_tags: [],
  recent_tags: [],
  recent_search: {},
  
  convert_flat_tag_list: function(tags) {
    if (tags == "" || tags == null) {
      return []
    }

    return tags.match(/\S+/g).sort().map(function(x) {
      return [x, 0, 0]
    })
  },

  init: function(uploaded_tags, recent_tags, artist_tags) {
    this.uploaded_tags = this.convert_flat_tag_list(uploaded_tags)
    this.recent_tags = this.convert_flat_tag_list(recent_tags)

    if (artist_tags) {
      this.build_all({"Artists": artist_tags})
    } else {
      this.build_all({})
    }
  },

  toggle: function(link, field) {
    var field = $(field)
    var tags = field.value.match(/\S+/g) || []
    var tag = (link.innerText || link.textContent).replace(/ /g, "_")

    if (tags.include(tag)) {
      field.value = tags.without(tag).join(" ") + " "
    } else {
      field.value = tags.concat([tag]).join(" ") + " "
    }

    field.selectionStart = field.value.length
    this.build_all(this.recent_search)
    return false
  },

  build_html: function(key, tags) {
    if (tags == null || tags.size() == 0) {
      return ""
    }

    var html = ""
    var current = $F("post_tags").match(/\S+/g) || []

    html += '<div class="tag-column">'
    html += '<h6><em>' + key.replace(/_/g, " ") + '</em></h6>'
  
    for (var i=0; i<tags.size(); ++i) {
      var tag = tags[i]
      html += ('<a class="tag-type-' + tag[2] + '" href="/post/index?tags=' + encodeURIComponent(tag[0]) + '" onclick="RelatedTags.toggle(this, \'post_tags\'); return false"')
    
      if (current.include(tag[0])) {
        html += ' style="background: rgb(0, 111, 250); color: white;"'
      }
    
      html += '>' + tag[0].escapeHTML().replace(/_/g, " ") + '</a><br> '
    }
    html += '</div>'

    return html
  },

  build_all: function(tags) {
    this.recent_search = tags
  
    var html = this.build_html("Favorite Tags", this.uploaded_tags) + this.build_html("Recent Tags", this.recent_tags)
    var keys = []

    for (key in tags) {
      keys.push(key)
    }
  
    keys.sort()

    for (var i=0; i<keys.size(); ++i) {
      html += this.build_html(keys[i], tags[keys[i]])
    }
  
    $("related").update(html)
  },

  find: function(field, type) {
    $("related").update("<em>Fetching...</em>")
    var field = $(field)
		var tags = null
		var text_length = field.value.length
		
		if (field.selectionStart != text_length) {
			var a = field.selectionStart
			var b = field.selectionStart
			
			while ((a > 0) && field.value[a] != " ") {
				a -= 1
			}
			
			if (field.value[a] == " ") {
				a += 1
			}
			
			while ((b < text_length) && field.value[b] != " ") {
				b += 1
			}
			
			tags = field.value.slice(a, b)
		} else {
			tags = field.value
		}

    var params = {"tags": tags}
    if (type) {
      params["type"] = type
    }
  
    new Ajax.Request("/tag/related.json", {
      method: 'get',
      parameters: params,
      onComplete: function(resp) {
        var resp = resp.responseJSON
        var converted = this.convert_related_js_response(resp)
        this.build_all(converted)
      }.bind(this)
    })
  },

  convert_related_js_response: function(resp) {
    var converted = {}
  
    for (k in resp) {
      var tags = resp[k].sortBy(function(x) {return x[0]})
      converted[k] = tags
    }

    return converted
  },

  find_artist: function(url) {
    if (url.match(/^http/)) {
      new Ajax.Request("/artist/index.json", {
        method: "get",
        parameters: {
          "url": url,
          "limit": "10"
        },
        onComplete: function(resp) {
          var resp = resp.responseJSON
          this.build_all({"Artist": resp.map(function(x) {return [x.name,0,1]})})
        }.bind(this)
      })
    }
  }
}
