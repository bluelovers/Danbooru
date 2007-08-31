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
