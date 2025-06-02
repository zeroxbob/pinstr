class SessionsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:create, :destroy]
  
  def new
    # Just renders the login form
  end

  def create
    pubkey = params[:public_key]
    Rails.logger.info("Login attempt with pubkey: #{pubkey || 'nil'}")
    
    if pubkey.blank?
      Rails.logger.error("Login failed: No public key provided")
      render json: { error: "No public key provided" }, status: :unprocessable_entity
      return
    end

    user = User.find_or_create_by_public_key(pubkey)
    if user
      session[:user_id] = user.id
      Rails.logger.info("User logged in: #{user.id} with pubkey: #{pubkey}")
      render json: { success: true, message: "Logged in successfully" }
    else
      Rails.logger.error("Login failed: Failed to create or find user with pubkey: #{pubkey}")
      render json: { error: "Failed to log in" }, status: :unprocessable_entity
    end
  end

  def destroy
    reset_session
    render json: { success: true, message: "Logged out successfully" }
  end
end