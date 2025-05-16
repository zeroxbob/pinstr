# Development-only controller for testing authentication
class DevLoginController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:login]
  
  def login
    # Only allow in development mode
    unless Rails.env.development?
      render plain: "Not allowed in production", status: :forbidden
      return
    end
    
    # Use our test user (ID 244)
    session[:user_id] = 244
    flash[:notice] = "Logged in as test user"
    redirect_to bookmarks_path
  end
end
