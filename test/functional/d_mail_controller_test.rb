require File.dirname(__FILE__) + '/../test_helper'
require 'd_mail_controller'

# Re-raise errors caught by the controller.
class DMailController; def rescue_action(e) raise e end; end

class DMailControllerTest < Test::Unit::TestCase
  def setup
    @controller = DMailController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
