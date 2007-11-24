var Note = Class.create()
Note.zindex = 0
Note.counter = -1
Note.all = []
Note.display = true

Note.show = function() {
/* 	for (var i=0; i<Note.all.length; ++i) { */
/* 		Note.all[i].bodyHide() */
/* 		Note.all[i].elements.box.style.display = "block" */
/* 	} */
	$('note-container').style.visibility = "visible"
}

Note.hide = function() {
/* 	for (var i=0; i<Note.all.length; ++i) { */
/* 		Note.all[i].bodyHide() */
/* 		Note.all[i].elements.box.style.display = "none" */
/* 	} */
	$('note-container').style.visibility = "hidden"
}

Note.find = function(id) {
	for (var i = 0; i<Note.all.length; ++i) {
		if (Note.all[i].id == id) {
			return Note.all[i]
		}
	}

	return null
}

Note.toggle = function() {
	if (Note.display) {
		Note.hide()
		Note.display = false
	} else {
		Note.show()
		Note.display = true
	}
}

Note.updateNoteCount = function() {
	if (Note.all.length > 0) {
		var label = ""

		if (Note.all.length == 1)
			label = "note"
		else
			label = "notes"

		$('note-count').innerHTML = "This post has <a href=\"/note/history?post_id=" + Note.post_id + "\">" + Note.all.length + " " + label + "</a>"
	} else {
		$('note-count').innerHTML = ""
	}
};

Note.create = function() {
	var note = ''
	note += '<div class="note-box unsaved" style="width: 150px; height: 150px; '
	note += 'top: ' + ($('image').clientHeight / 2 - 75) + 'px; '
	note += 'left: ' + ($('image').clientWidth / 2 - 75) + 'px;" '
	note += 'id="note-box-' + Note.counter + '">'
	note += '<div class="note-corner" id="note-corner-' + Note.counter + '"></div>'
	note += '</div>'
	note += '<div class="note-body" title="Click to edit" id="note-body-' + Note.counter + '"></div>'
	new Insertion.Bottom('note-container', note)
	Note.all.push(new Note(Note.counter, true, ''))
	Note.counter -= 1
};

Note.prototype = {
	// Necessary because addEventListener/removeEventListener don't play nice with
	// different instantiations of the same method.
	bind: function(method_name) {
		if (!this.bound_methods) {
			this.bound_methods = new Object()
		}

		if (!this.bound_methods[method_name]) {
			this.bound_methods[method_name] = this[method_name].bindAsEventListener(this)
		}

		return this.bound_methods[method_name]
	},

	initialize: function(id, is_new, raw_body) {
		this.id = id
		this.is_new = is_new

		// get the elements
		this.elements = {
			box:		$('note-box-' + this.id),
			corner:		$('note-corner-' + this.id),
			body:		$('note-body-' + this.id),
			image:		$('image')
		}

		// for scaling
		this.fullsize = {
			left:           this.elements.box.offsetLeft,
			top:            this.elements.box.offsetTop,
			width:          this.elements.box.clientWidth,
			height:         this.elements.box.clientHeight
		}
		if (this.elements.image.scale_factor == null)
			this.elements.image.scale_factor = 1

		// store the data
		this.old = {
			raw_body:       raw_body,
			formatted_body: this.elements.body.innerHTML
		}
		for (p in this.fullsize)
			this.old[p] = this.fullsize[p]

		// IE opacity
		if(/MSIE/.test(navigator.userAgent) && !window.opera)
			Element.setStyle(this.elements.box, {opacity: 0.5})

		// reposition the box to be relative to the image
		// is this needed? in what browsers?
		this.elements.box.style.top = this.elements.box.offsetTop + "px"
		this.elements.box.style.left = this.elements.box.offsetLeft + "px"
		
		if (is_new && raw_body == '') {
			this.bodyfit = true
			this.elements.body.style.height = "100px"
		}

		// attach the event listeners
		Event.observe(this.elements.box, "mousedown", this.bind("dragStart"), false)
		Event.observe(this.elements.box, "mouseout", this.bind("bodyHideTimer"), false)
		Event.observe(this.elements.box, "mouseover", this.bind("bodyShow"), false)
		Event.observe(this.elements.corner, "mousedown", this.bind("resizeStart"), false)
		Event.observe(this.elements.body, "mouseover", this.bind("bodyShow"), false)
		Event.observe(this.elements.body, "mouseout", this.bind("bodyHideTimer"), false)
		Event.observe(this.elements.body, "click", this.bind("showEditBox"), false)
	},

	textValue: function() {
		return this.old.raw_body.replace(/(?:^\s+|\s+$)/, '')
	},

	hideEditBox: function(e) {
		var editBox = $('edit-box')

		if (editBox != null) {
			var boxid = editBox.noteid
			// redundant?
			Event.stopObserving('edit-box', 'mousedown', this.bind("editDragStart"), false)
			Event.stopObserving('note-save-' + boxid, 'click', this.bind("save"), false)
			Event.stopObserving('note-cancel-' + boxid, 'click', this.bind("cancel"), false)
			Event.stopObserving('note-remove-' + boxid, 'click', this.bind("remove"), false)
			Event.stopObserving('note-history-' + boxid, 'click', this.bind("history"), false)
			this.elements.editBox = null

			Element.remove('edit-box')
		}

	},

	showEditBox: function(e) {
		this.hideEditBox(e)

		var inject = ''
		Position.prepare()

		var top = Position.deltaY
		var left = Position.deltaX + 25

		inject += '<div id="edit-box" style="top: '+top+'px; left: '+left+'px; position: absolute; visibility: visible; z-index: 100; background: white; border: 1px solid black; padding: 12px;">'
		inject += '<form onsubmit="return false;" style="padding: 0; margin: 0;">'
		inject += '<textarea rows="7" id="edit-box-text" style="width: 350px; margin: 2px 2px 12px 2px;">' + this.textValue() + '</textarea>'
		inject += '<input type="submit" value="Save" name="save" id="note-save-' + this.id + '" />'
		inject += '<input type="submit" value="Cancel" name="cancel" id="note-cancel-' + this.id + '" />'
		inject += '<input type="submit" value="Remove" name="remove" id="note-remove-' + this.id + '" />'
		inject += '<input type="submit" value="History" name="history" id="note-history-' + this.id + '" />'
		inject += '</form>'
		inject += '</div>'

		new Insertion.Bottom('note-container', inject)

		$('edit-box').noteid = this.id

		Event.observe('edit-box', 'mousedown', this.bind("editDragStart"), false)

		Event.observe('note-save-' + this.id, 'click', this.bind("save"), false)
		Event.observe('note-cancel-' + this.id, 'click', this.bind("cancel"), false)
		Event.observe('note-remove-' + this.id, 'click', this.bind("remove"), false)
		Event.observe('note-history-' + this.id, 'click', this.bind("history"), false)
		$("edit-box-text").focus()
	},

	bodyShow: function(e) {
		if (this.dragging)
			return

		if (this.hideTimer) {
			clearTimeout(this.hideTimer)
			this.hideTimer = null
		}

		if (Note.noteShowingBody == this) return
		if (Note.noteShowingBody) Note.noteShowingBody.bodyHide()
		Note.noteShowingBody = this
		
		if (Note.zindex >= 9) {		/* don't use more than 10 layers (+1 for the body, which will always be above all notes) */
			Note.zindex = 0
			for (var i=0; i< Note.all.length; ++i) {
				Note.all[i].elements.box.style.zIndex = 0
			}
		}

		this.elements.box.style.zIndex = ++Note.zindex
		this.elements.body.style.zIndex = 10
		this.elements.body.style.top = 0 + "px"
		this.elements.body.style.left = 0 + "px"

		var dw = document.documentElement.scrollWidth
//		alert([document.body.scrollWidth, document.body.offsetWidth, document.body.clientWidth, document.documentElement.scrollWidth, document.documentElement.offsetWidth, document.documentElement.clientWidth])
		this.elements.body.style.visibility = "hidden"
		this.elements.body.style.display = "block"
		if (!this.bodyfit) {
			this.elements.body.style.height = "auto"
			this.elements.body.style.minWidth = "140px"
			var w, h, lo, hi, x, last
			w = this.elements.body.offsetWidth
			h = this.elements.body.offsetHeight
			if (w/h < 1.6180339887) {
				/* for tall notes (lots of text), find more pleasant proportions */
				lo = 140, hi = 400
				do {
					last = w
					x = (lo+hi)/2
					this.elements.body.style.minWidth = x + "px"
					w = this.elements.body.offsetWidth
					h = this.elements.body.offsetHeight
					if (w/h < 1.6180339887) lo = x
					else hi = x
				} while ((lo < hi) && (w > last))
			} else if (this.elements.body.scrollWidth <= this.elements.body.clientWidth) {	/* scroll test required by Firefox */
				/* for short notes (often a single line), make the box no wider than necessary */
				lo = 20, hi = w
				do {
					x = (lo+hi)/2
					this.elements.body.style.minWidth = x + "px"
					if (this.elements.body.offsetHeight > h) lo = x
					else hi = x
				} while ((hi - lo) > 4)
				if (this.elements.body.offsetHeight > h)
					this.elements.body.style.minWidth = hi + "px"
			}
			this.bodyfit = true
		}
		this.elements.body.style.top = (this.elements.box.offsetTop + this.elements.box.clientHeight + 5) + "px"
		/* keep the box within the document's width */
		var l = 0, e = this.elements.box
		do { l += e.offsetLeft } while (e = e.offsetParent)
		l += this.elements.body.offsetWidth + 10 - dw
		if (l > 0)
			this.elements.body.style.left = this.elements.box.offsetLeft - l + "px"
		else
			this.elements.body.style.left = this.elements.box.offsetLeft + "px"
		this.elements.body.style.visibility = "visible"
	},

	bodyHideTimer: function(e) {
		this.hideTimer = setTimeout(this.bind("bodyHide"), 250)
	},

	bodyHide: function(e) {
		this.elements.body.style.display = "none"
		if (Note.noteShowingBody == this) Note.noteShowingBody = null
	},

	dragStart: function(e) {
		Event.observe(document.documentElement, 'mousemove', this.bind("drag"), false)
		Event.observe(document.documentElement, 'mouseup', this.bind("dragStop"), false)
		document.onselectstart = function() {return false}

		this.cursorStartX = Event.pointerX(e)
		this.cursorStartY = Event.pointerY(e)
		this.boxStartX = this.elements.box.offsetLeft
		this.boxStartY = this.elements.box.offsetTop
		this.boundsX = new ClipRange(5,
			this.elements.image.clientWidth
			- this.elements.box.clientWidth - 5)
		this.boundsY = new ClipRange(5,
			this.elements.image.clientHeight
			- this.elements.box.clientHeight - 5)
		this.dragging = true

		this.bodyHide()
	},

	dragStop: function(e) {
		Event.stopObserving(document.documentElement, 'mousemove', this.bind("drag"), false)
		Event.stopObserving(document.documentElement, 'mouseup', this.bind("dragStop"), false)
		document.onselectstart = function() {return true}

		this.cursorStartX = null
		this.cursorStartY = null
		this.boxStartX = null
		this.boxStartY = null
		this.boundsX = null
		this.boundsY = null
		this.dragging = false

		this.bodyShow()
	},

	adjustScale: function() {
		var ratio = this.elements.image.scale_factor
		for (p in this.fullsize)
			this.elements.box.style[p] = this.fullsize[p] * ratio + 'px'
	},

	drag: function(e) {
		var left = this.boxStartX + Event.pointerX(e) - this.cursorStartX
		var top = this.boxStartY + Event.pointerY(e) - this.cursorStartY
		left = this.boundsX.clip(left)
		top = this.boundsY.clip(top)
		
		this.elements.box.style.left = left + 'px'
		this.elements.box.style.top = top + 'px'
		var ratio = this.elements.image.scale_factor
		this.fullsize.left = left / ratio
		this.fullsize.top = top / ratio

		Event.stop(e)
	},

	resizeStart: function(e) {
		this.cursorStartX = Event.pointerX(e)
		this.cursorStartY = Event.pointerY(e)
		this.boxStartWidth = this.elements.box.clientWidth
		this.boxStartHeight = this.elements.box.clientHeight
		this.boxStartX = this.elements.box.offsetLeft
		this.boxStartY = this.elements.box.offsetTop
		this.boundsX = new ClipRange(10,
			this.elements.image.clientWidth - this.boxStartX - 5)
		this.boundsY = new ClipRange(10,
			this.elements.image.clientHeight - this.boxStartY - 5)
		this.dragging = true

		Event.stopObserving(document.documentElement, 'mousemove', this.bind("drag"), false)
		Event.stopObserving(document.documentElement, 'mouseup', this.bind("dragStop"), false)
		Event.observe(document.documentElement, 'mousemove', this.bind("resize"), false)
		Event.observe(document.documentElement, 'mouseup', this.bind("resizeStop"), false)

		Event.stop(e)

		this.bodyHide()
	},

	resizeStop: function(e) {
		Event.stopObserving(document.documentElement, 'mousemove', this.bind("resize"), false)
		Event.stopObserving(document.documentElement, 'mouseup', this.bind("resizeStop"), false)

		this.boxCursorStartX = null
		this.boxCursorStartY = null
		this.boxStartWidth = null
		this.boxStartHeight = null
		this.boxStartX = null
		this.boxStartY = null
		this.boundsX = null
		this.boundsY = null
		this.dragging = false

		Event.stop(e)
	},

	resize: function(e) {
		var width = this.boxStartWidth + Event.pointerX(e) - this.cursorStartX
		var height = this.boxStartHeight + Event.pointerY(e) - this.cursorStartY
		width = this.boundsX.clip(width)
		height = this.boundsY.clip(height)

		this.elements.box.style.width = width + "px"
		this.elements.box.style.height = height + "px"
		var ratio = this.elements.image.scale_factor
		this.fullsize.width = width / ratio
		this.fullsize.height = height / ratio

		Event.stop(e)
	},

	editDragStart: function(e) {
		var node = Event.element(e).nodeName
		if (node != 'FORM' && node != 'DIV')
			return

		Event.observe(document.documentElement, 'mousemove', this.bind("editDrag"), false)
		Event.observe(document.documentElement, 'mouseup', this.bind("editDragStop"), false)
		document.onselectstart = function() {return false}

		this.elements.editBox = $('edit-box');
		this.cursorStartX = Event.pointerX(e)
		this.cursorStartY = Event.pointerY(e)
		this.editStartX = this.elements.editBox.offsetLeft
		this.editStartY = this.elements.editBox.offsetTop
		this.dragging = true
	},

	editDragStop: function(e) {
		Event.stopObserving(document.documentElement, 'mousemove', this.bind("editDrag"), false)
		Event.stopObserving(document.documentElement, 'mouseup', this.bind("editDragStop"), false)
		document.onselectstart = function() {return true}

		this.cursorStartX = null
		this.cursorStartY = null
		this.editStartX = null
		this.editStartY = null
		this.dragging = false
	},

	editDrag: function(e) {
		var left = this.editStartX + Event.pointerX(e) - this.cursorStartX
		var top = this.editStartY + Event.pointerY(e) - this.cursorStartY

		this.elements.editBox.style.left = left + 'px'
		this.elements.editBox.style.top = top + 'px'

		Event.stop(e)
	},

	save: function(e) {
		var note = this
		for (p in this.fullsize)
			this.old[p] = this.fullsize[p]
		this.old.raw_body = $('edit-box-text').value
		this.old.formatted_body = this.textValue()
		this.elements.body.innerHTML = this.textValue()	// FIXME? this is not quite how the note will look (filtered elems, <tn>...). the user won't input a <script> that only damages him, but it might be nice to "preview" the <tn> here

		this.hideEditBox(e)
		this.bodyHide()
		this.bodyfit = false

		var params = []
		params.push("note%5Bx%5D=" + this.old.left)
		params.push("note%5By%5D=" + this.old.top)
		params.push("note%5Bwidth%5D=" + this.old.width)
		params.push("note%5Bheight%5D=" + this.old.height)
		params.push("note%5Bbody%5D=" + encodeURIComponent(this.old.raw_body))

		if (this.is_new) {
			params.push("note%5Bpost_id%5D=" + Note.post_id)
		}

		notice("Saving note...")
		new Ajax.Request('/note/update/' + this.id, {
			asynchronous: true,
			method: 'post',
			parameters: params.join("&"),
			onFailure: function(req) {
				if (req.responseText) {
					var response = eval("(" + req.responseText + ")")
					notice("Error: " + response.reason)
				} else if (req.status) {
					notice("Error: " + req.status + " " + req.statusText)
				} else {
					notice("Error: unknown")
				}
				note.elements.box.addClassName('unsaved')
			},
			onException: function(req,exc) {
				notice("Exception: <pre>"+exc+"</pre>")
				note.elements.box.addClassName('unsaved')
			},
			onSuccess: function(req) {
				notice("Note saved")
				var response = eval("(" + req.responseText + ")")
				if (response.old_id < 0) {
					note.is_new = false
					note.id = response.new_id
					note.elements.box.id = 'note-box-' + note.id
					note.elements.body.id = 'note-body-' + note.id
					note.elements.corner.id = 'note-corner-' + note.id
				}
				note.elements.body.innerHTML = response.formatted_body
				note.elements.box.removeClassName('unsaved')
			}
		})

		Event.stop(e)
	},

	cancel: function(e) {
		this.hideEditBox(e)
		this.bodyHide()

		var ratio = this.elements.image.scale_factor
		for (p in this.fullsize) {
			this.fullsize[p] = this.old[p]
			this.elements.box.style[p] = this.fullsize[p] * ratio + 'px'
		}
		this.elements.body.innerHTML = this.old.formatted_body

		Event.stop(e)
	},

	removeCleanup: function() {
		Element.remove(this.elements.box)
		Element.remove(this.elements.body)

		var allTemp = []
		for (i=0; i<Note.all.length; ++i) {
			if (Note.all[i].id != this.id) {
				allTemp.push(Note.all[i])
			}
		}

		Note.all = allTemp
		Note.updateNoteCount()
	},

	remove: function(e) {
		this.hideEditBox(e)
		this.bodyHide()

		if (this.is_new) {
			this.removeCleanup()
			notice("Note removed")

		} else {
			notice("Removing note...")

			new Ajax.Request('/note/update/' + this.id, {
				asynchronous: true,
				method: 'post',
				postBody: 'note[is_active]=0',
				onComplete: function(req) {
					var resp = eval("(" + req.responseText + ")")
					if (req.status == 403) {
						notice("Access denied")
					} else if (req.status == 500) {
						notice("Error: " + resp.reason)
					} else {
						Note.find(parseInt(resp.old_id)).removeCleanup()
						notice("Note removed")
					}
				}
			})
		}

		Event.stop(e)
	},

	history: function(e) {
		this.hideEditBox(e)

		if (this.is_new) {
			notice("This note has no history")
		} else {
			location.pathname = '/note/history/' + this.id
		}
	}
}
