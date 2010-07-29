module TestJanitorHelper
  def positive_score_approval_percentage(approver)
    positive_count = Post.count(:conditions => ["approver_id = ? AND score > 1", approver.id])
    total_count = Post.count(:conditions => ["approver_id = ?", approver.id])
    number_with_precision(100 * positive_count.to_f / total_count.to_f, :precision => 1)
  end

  def negative_score_approval_percentage(approver)
    negative_count = Post.count(:conditions => ["approver_id = ? AND score < -1", approver.id])
    total_count = Post.count(:conditions => ["approver_id = ?", approver.id])
    number_with_precision(100 * negative_count.to_f / total_count.to_f, :precision => 1)
  end
end
