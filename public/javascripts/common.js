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

