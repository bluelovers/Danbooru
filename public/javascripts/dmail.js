Dmail = {}

Dmail.respond = function(to) {
  $("dmail_to").value = to
  $("dmail_body").value = "[quote]You said:\n" + $("dmail_body").value.replace(/\[quote\](?:.|\n)+?\[\/quote\]\n*/gm, "") + "[/quote]\n\n"
  $("response").show()
}

Dmail.highlight = function(id) {
  var checkbox = $("dmail[" + id + "]")
  var row = $("row-" + id)
  
  if (checkbox.checked) {
    row.old_class = row.className
    row.className = "highlight"
  } else {
    row.className = row.old_class
  }
}

Dmail.select_all = function() {
  var checkboxes = document.getElementsByClassName("checkbox")
  
  for (var i=0; i<checkboxes.length; ++i) {
    checkboxes[i].checked = true
    checkboxes[i].old_class = checkboxes[i].className
    var id = checkboxes[i].id.match(/dmail\[(\d+)\]/)[1]
    this.highlight(id)
  }
}
