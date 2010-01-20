class Presenter
protected
  def h(str)
    CGI.escapeHTML(str)
  end
end
