function toggleImageResize() {
    var img = $("image");

    if ((img.full_size == 1) || (img.full_size == null)) {
        img.full_size = 0;
        img.original_width = img.width;
        img.original_height = img.height;
        var client_width = $("right-col").clientWidth - 15;
        var client_height = $("right-col").clientHeight;

        if (img.width > client_width) {
            var ratio = client_width / img.width;
            img.width = img.width * ratio;
            img.height = img.height * ratio;
        }
    } else {
        img.full_size = 1;
        img.width = img.original_width;
        img.height = img.original_height;
    }
}
