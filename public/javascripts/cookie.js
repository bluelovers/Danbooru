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
