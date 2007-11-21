function toggleImageResize() {
  var img = $("image");

  if ((img.scale_factor == 1) || (img.scale_factor == null)) {
    img.original_width = img.width;
    img.original_height = img.height;
    var client_width = $("right-col").clientWidth - 15;
    var client_height = $("right-col").clientHeight;

    if (img.width > client_width) {
      var ratio = img.scale_factor = client_width / img.width;
      img.width = img.width * ratio;
      img.height = img.height * ratio;
    }
  } else {
    img.scale_factor = 1;
    img.width = img.original_width;
    img.height = img.original_height;
  }
  if (window.Note) {
    for (var i=0; i<window.Note.all.length; ++i) {
      window.Note.all[i].adjustScale()
    }
  }
}

