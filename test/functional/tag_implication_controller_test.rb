require File.dirname(__FILE__) + '/../test_helper'
require 'tag_implication_controller'

# Re-raise errors caught by the controller.
class TagImplicationController; def rescue_action(e) raise e end; end

class TagImplicationControllerTest < Test::Unit::TestCase
  def setup
    @controller = TagImplicationController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
