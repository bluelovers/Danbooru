var ts_scripts = []

function ts_add(id, name, script) {
  var row = document.createElement("tr")
  var row_name = document.createElement("td")
  var row_name_field = document.createElement("input")
  var row_script = document.createElement("td")
  var row_script_field = document.createElement("input")
  var row_options = document.createElement("td")
  var row_options_button = document.createElement("input")

  if (id != null) {
    row.script_id = id
    row.id = "ts-" + id
  } else {
    row.script_id = ts_scripts.length
    row.id = "ts-" + ts_scripts.length
    ts_scripts.push([ts_scripts.length, "", ""])
  }

  row_name_field.type = "text"
  row_name_field.size = 30
  row_name_field.className = "tag-script-names"
  if (name) {
    row_name_field.value = name
  }

  row_script_field.type = "text"
  row_script_field.size = 60
  row_script_field.className = "tag-script-values"
  if (script) {
    row_script_field.value = script
  }

  row_options_button.type = "button"
  row_options_button.value = "Delete"
  row_options_button.onclick = function() {ts_destroy(this.parentNode.parentNode); return false;}

  row_options.appendChild(row_options_button)
  row_script.appendChild(row_script_field)
  row_name.appendChild(row_name_field)

  row.appendChild(row_name)
  row.appendChild(row_script)
  row.appendChild(row_options)

  $('tag-scripts').appendChild(row)
}

function ts_save() {
  ts_scripts = []
  var names = $A(document.getElementsByClassName("tag-script-names")).pluck("value")
  var values = $A(document.getElementsByClassName("tag-script-values")).pluck("value")

  for (i=0; i<names.length; ++i) {
    ts_scripts.push([i, names[i], values[i]])
  }

  createCookie("tag-scripts", ts_scripts.toJSON())
}

function ts_destroy(row) {
  Element.remove(row)
  ts_scripts = ts_scripts.reject(function(x) {return x[0] == row.script_id})
  ts_save()
}

function ts_load() {
  if (readCookie("tag-scripts") != "") {
    ts_scripts = eval(readCookie("tag-scripts"))

    for (i=0; i<ts_scripts.length; ++i) {
      var id = ts_scripts[i][0]
      var name = ts_scripts[i][1]
      var script = ts_scripts[i][2]
      ts_add(id, name, script)
    }
  }
}

ts_load()
