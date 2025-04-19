class BookmarksController < ApplicationController
  before_action :authenticate_user!
  before_action :set_bookmark, only: %i[show edit update destroy]

  # GET /bookmarks
  def index
    @bookmarks = current_user.bookmarks
  end

  # GET /bookmarks/:id
  def show
  end

  # GET /bookmarks/new
  def new
    @bookmark = current_user.bookmarks.new
  end

  # POST /bookmarks
  def create
    # Prepare event data for signing
    signed_event_param = params[:signed_event]

    if signed_event_param
      signed_event = handle_signed_event(signed_event_param)
      Bookmark.create!(signed_event) if signed_event

      # Optionally, send to Nostr relays
      render json: { status: 'success', message: 'Bookmark was successfully created and sent to Nostr.' }
    else
      render json: { status: 'error', message: 'Signing failed.' }, status: :unprocessable_entity
    end
  end

  # GET /bookmarks/:id/edit
  def edit
  end

  # PATCH/PUT /bookmarks/:id
  def update
    if @bookmark.update(bookmark_params)
      redirect_to @bookmark, notice: 'Bookmark was successfully updated.'
    else
      render :edit
    end
  end

  # DELETE /bookmarks/:id
  def destroy
    @bookmark.destroy
    redirect_to bookmarks_url, notice: 'Bookmark was successfully destroyed.'
  end

  private

  def authenticate_user!
    # Logic for authenticating user
  end

  def set_bookmark
    @bookmark = current_user.bookmarks.find(params[:id])
  end

  def bookmark_params
    params.require(:bookmark).permit(:title, :url, :description)
  end

  def handle_signed_event(signed_event_param)
    # Sample parse logic - customize as needed
    JSON.parse(signed_event_param) rescue nil
  end
end
