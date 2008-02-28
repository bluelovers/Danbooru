var DANBOORU_VERSION = {
  major: 1,
  minor: 13,
  build: 0
}

function notice(msg) {
  $('notice').update(msg).show()
}

var ClipRange = Class.create({
  initialize: function(min, max) {
    if (min > max)  {
      throw "paramError"
    }

    this.min = min
    this.max = max
  },

  clip: function(x) {
    if (x < this.min) {
      return this.min
    }
    
    if (x > this.max) {
      return this.max
    }
    
    return x
  }
})
