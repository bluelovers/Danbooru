module ReportHelper
  def build_line_graph(title, data)
    if Object.const_defined?(:Scruffy)
      graph = Scruffy::Graph.new(:title => title)
      data.each do |name, d|
        graph.add(:line, name, d)
      end
      return graph.render
    else
      return ""
    end
  end
end
