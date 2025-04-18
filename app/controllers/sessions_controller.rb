class SessionsController < ApplicationController
  def create
    pubkey = params[:public_key]
    if pubkey.blank?
      flash[:alert] = "No public key provided"
      redirect_to root_path and return
    end

    user = User.find_or_create_by_public_key(pubkey)
    if user
      session[:user_id] = user.id
      flash[:notice] = "Logged in with public key #{pubkey}"
    else
      flash[:alert] = "Failed to log in"
    end
    redirect_to root_path
  end

  def destroy
    reset_session
    flash[:notice] = "Logged out"
    redirect_to root_path
  end
end
