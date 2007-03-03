module MimeTypes
	MIME_TO_EXT = {
		"image/gif" => "gif",
		"image/png" => "png",
		"image/jpeg" => "jpg",
		"image/bmp" => "bmp",
		"image/tiff" => "tiff",
		"image/svg+xml" => "svg",
		"image/x-photoshop" => "psd",
		"application/pdf" => "pdf",
		"application/postscript" => "ps",
		"application/rar" => "rar",
		"application/zip" => "zip",
		"application/ogg" => "ogg",
		"application/x-shockwave-flash" => "swf",
		"application/x-tar" => "tar",
		"application/x-bittorrent" => "torrent",
		"application/x-gzip" => "gz",
		"application/x-tgz" => "tgz",
		"audio/mpeg" => "mp3",
		"text/plain" => "txt",
		"text/html" => "html",
		"text/richtext" => "rtf",
		"text/xml" => "xml",
		"video/mpeg" => "mpg",
		"video/quicktime" => "qt",
		"video/x-msvideo" => "avi",
		"video/x-ms-asf" => "asf",
		"video/x-ms-wmv" => "wmv"
	}

	MAGIC = FileMagic.new(FileMagic::MAGIC_MIME)

	def check_mime_type
		ext = MIME_TO_EXT[MAGIC.file(tempfile_path)] || file_ext
		raise "illegal or unknown file type" if ["", "html", "xml"].include?(ext)
		self.file_ext = ext
	end
end
