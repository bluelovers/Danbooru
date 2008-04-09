if true
  path = "public/javascripts"

  if not File.stat(path).writable?
    raise "Path must be writable: %s" % path
  end
end
