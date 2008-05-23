require File.dirname(__FILE__) + '/../test_helper'

class UserControllerTest < ActionController::TestCase
  def test_show
    raise NotImplementedError
  end
  
  def test_invites
    raise NotImplementedError
  end
  
  def test_home
    raise NotImplementedError
  end
  
  def test_index
    raise NotImplementedError
  end
  
  def test_authenticate
    raise NotImplementedError
  end
  
  def test_create
    raise NotImplementedError
  end
    
  def test_update
    raise NotImplementedError
  end
  
  def test_reset_password
    raise NotImplementedError
  end
  
  def test_block
    raise NotImplementedError
  end
  
  def test_show_blocked_users
    raise NotImplementedError
  end
  
  if CONFIG["enable_account_email_activation"]
    def test_resend_confirmation
      raise NotImplementedError
    end
    
    def test_activate_user
      raise NotImplementedError
    end
  end
end
