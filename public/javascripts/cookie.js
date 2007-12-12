Cookie = {}

Cookie.put = function(name, value, days) {
  if (days == null) {
    days = 365
  }

  var date = new Date()
  date.setTime(date.getTime() + (days * 24 * 60 * 60 * 1000))
  var expires = "; expires=" + date.toGMTString()
  document.cookie = name + "=" + value + expires + "; path=/"
}

Cookie.get = function(name) {
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

Cookie.remove = function(name) {
  Cookie.put(name, "", -1)
}

Cookie.unescape = function(val) {
  return window.unescape(val.replace(/\+/g, " "))
}

Cookie.setup = function() {
  if (this.get("has_mail") == "1") {
    $("has-mail-notice").show()
  }
  
  if (this.get("forum_updated") == "1") {
    $("forum-link").className = "forum-update"
  }
  
  if (this.get("block_reason") != "") {
    $("block-reason").innerHTML = this.unescape(this.get("block_reason"))
    $("block-reason").show()
  }
}
