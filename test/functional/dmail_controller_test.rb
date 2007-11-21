require File.dirname(__FILE__) + '/../test_helper'
require 'dmail_controller'

# Re-raise errors caught by the controller.
class DmailController; def rescue_action(e) raise e end; end

class DmailControllerTest < Test::Unit::TestCase
  def setup
    @controller = DmailController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
