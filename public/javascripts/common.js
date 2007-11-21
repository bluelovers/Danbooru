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
  $('notice').show()
  $('notice').innerHTML = msg
}

var ClipRange = Class.create()
ClipRange.prototype = {
  initialize: function(min, max) {
    if (min > max) throw "paramError"
      this.min = min
      this.max = max
    },
    clip: function(x) {
      if (x < this.min) return this.min
      if (x > this.max) return this.max
      return x
  }
}
