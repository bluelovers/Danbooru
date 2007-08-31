require File.dirname(__FILE__) + '/../test_helper'
require 'invite_controller'

# Re-raise errors caught by the controller.
class InviteController; def rescue_action(e) raise e end; end

class InviteControllerTest < Test::Unit::TestCase
  def setup
    @controller = InviteController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
