var Note = Class.create()
Note.zindex = 0
Note.counter = -1
Note.all = []
Note.display = true

Note.show = function() {
	for (var i=0; i<Note.all.length; ++i) {
		Note.all[i].bodyHide()
		Note.all[i].elements.box.style.display = "block"
	}
}

Note.hide = function() {
	for (var i=0; i<Note.all.length; ++i) {
		Note.all[i].bodyHide()
		Note.all[i].elements.box.style.display = "none"
	}
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
	note += '<div class="note-box" style="width: 150px; height: 150px; '
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

		// store the data
		this.old = {
			left:           this.elements.box.offsetLeft,
			top:            this.elements.box.offsetTop,
			width:          this.elements.box.clientWidth,
			height:         this.elements.box.clientHeight,
			raw_body:       raw_body,
			formatted_body: this.elements.body.innerHTML
		}

		// IE opacity
		if(/MSIE/.test(navigator.userAgent) && !window.opera)
			Element.setStyle(this.elements.box, {opacity: 0.5})

		// reposition the box to be relative to the image

		this.elements.box.style.top = this.elements.box.offsetTop + "px"
		this.elements.box.style.left = this.elements.box.offsetLeft + "px"

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

		inject += '<div id="edit-box" style="width: 375px; height: 150px; top: '+top+'px; left: '+left+'px; position: absolute; z-index: 100; background: white; border: 1px solid black; padding: 1em;">'
		inject += '<form onsubmit="return false;">'
		inject += '<textarea rows="6" id="edit-box-text" style="width: 95%; margin-bottom: 1em;">' + this.textValue() + '</textarea>'
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

		// hide the other notes
		if (Note.all) {
			for (var i=0; i<Note.all.length; ++i) {
				if (Note.all[i].id != this.id) {
					Note.all[i].bodyHide()
				}
			}
		}

		this.elements.box.style.zIndex = ++Note.zindex
		this.elements.body.style.zIndex = Note.zindex
		this.elements.body.style.top = (this.elements.box.offsetTop + this.elements.box.clientHeight + 5) + "px"
		this.elements.body.style.left = this.elements.box.offsetLeft + "px"
		this.elements.body.style.display = "block"
	},

	bodyHideTimer: function(e) {
		this.hideTimer = setTimeout(this.bind("bodyHide"), 250)
	},

	bodyHide: function(e) {
		this.elements.body.style.display = "none"
	},

	dragStart: function(e) {
		Event.observe(document.documentElement, 'mousemove', this.bind("drag"), false)
		Event.observe(document.documentElement, 'mouseup', this.bind("dragStop"), false)
		document.onselectstart = function() {return false}

		this.cursorStartX = Event.pointerX(e)
		this.cursorStartY = Event.pointerY(e)
		this.boxStartX = this.elements.box.offsetLeft
		this.boxStartY = this.elements.box.offsetTop
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
		this.dragging = false

		this.bodyShow()
	},

	drag: function(e) {
		var left = this.boxStartX + Event.pointerX(e) - this.cursorStartX
		var top = this.boxStartY + Event.pointerY(e) - this.cursorStartY
		var bound

		bound = 5
		if (left < bound)
			left = bound

		bound = this.elements.image.clientWidth - this.elements.box.clientWidth - 5
		if (left > bound)
			left = bound

		bound = 5
		if (top < bound)
			top = bound

		bound = this.elements.image.clientHeight - this.elements.box.clientHeight - 5
		if (top > bound)
			top = bound

		this.elements.box.style.left = left + 'px'
		this.elements.box.style.top = top + 'px'

		Event.stop(e)
	},

	resizeStart: function(e) {
		this.cursorStartX = Event.pointerX(e)
		this.cursorStartY = Event.pointerY(e)
		this.boxStartWidth = this.elements.box.clientWidth
		this.boxStartHeight = this.elements.box.clientHeight
		this.boxStartX = this.elements.box.offsetLeft
		this.boxStartY = this.elements.box.offsetTop
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
		this.dragging = false

		Event.stop(e)
	},

	resize: function(e) {
		var w = this.boxStartWidth + Event.pointerX(e) - this.cursorStartX
		var h = this.boxStartHeight + Event.pointerY(e) - this.cursorStartY
		var bound

		if (w < 10)
			w = 10

		bound = this.elements.image.clientWidth - this.boxStartX - 5
		if (w > bound)
			w = bound

		if (h < 10)
			h = 10

		bound = this.elements.image.clientHeight - this.boxStartY - 5
		if (h > bound)
			h = bound

		this.elements.box.style.width = w + "px"
		this.elements.box.style.height = h + "px"
		this.elements.box.style.left = this.boxStartX + "px"
		this.elements.box.style.top = this.boxStartY + "px"

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
		this.old.left = this.elements.box.offsetLeft
		this.old.top = this.elements.box.offsetTop
		this.old.width = this.elements.box.clientWidth
		this.old.height = this.elements.box.clientHeight
		this.old.raw_body = $('edit-box-text').value
		this.old.formatted_body = this.textValue()
		this.elements.body.innerHTML = this.textValue()

		this.hideEditBox(e)
		this.bodyHide()

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
			},
			onException: function(req,exc) {
				notice("Exception: <pre>"+exc+"</pre>")
			},
			onSuccess: function(req) {
				notice("Note saved")
				var response = eval("(" + req.responseText + ")")
				if (response.old_id < 0) {
					var n = Note.find(response.old_id)
					n.is_new = false
					n.id = response.new_id
					n.elements.box.id = 'note-box-' + n.id
					n.elements.body.id = 'note-body-' + n.id
					n.elements.corner.id = 'note-corner-' + n.id
				}
				$("note-body-" + response.new_id).innerHTML = response.formatted_body
			}
		})

		Event.stop(e)
	},

	cancel: function(e) {
		this.hideEditBox(e)
		this.bodyHide()

		this.elements.box.style.top = this.old.top + "px"
		this.elements.box.style.left = this.old.left + "px"
		this.elements.box.style.width = this.old.width + "px"
		this.elements.box.style.height = this.old.height + "px"
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
