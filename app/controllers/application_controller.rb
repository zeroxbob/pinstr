class ApplicationController < ActionController::Base
  helper_method :current_user

  def current_user
    return if session[:user_id].blank?
    @current_user ||= User.find_by(id: session[:user_id])
  end

  def authenticate_user!
    unless current_user
      respond_to do |format|
        format.html {
          flash[:alert] = 'You must be logged in'
          redirect_to new_session_path
        }
        format.json {
          render json: { error: 'Authentication required' }, status: :unauthorized
        }
      end
    end
  end
end