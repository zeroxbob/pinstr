class AdminController < ApplicationController
  before_action :authenticate_user! # Assuming you have this method
  
  def dashboard
    @bookmarks = Bookmark.all.order(created_at: :desc)
  end
end