class BookmarksController < ApplicationController
  protect_from_forgery with: :exception

  def create
    signed_event = params[:signed_event]

    # Extract necessary fields from the signed event and map them
    bookmark_params = {
      title: signed_event['content'], # Assuming title is in 'content'
      url: request.referer || 'unknown', # Adjust as needed
      description: '',
      event_id: signed_event['id'],
      user_id: User.find_by(public_key: signed_event['pubkey'])&.id
    }

    @bookmark = Bookmark.new(bookmark_params)

    if @bookmark.save
      render json: { status: 'success', message: 'Bookmark was successfully created and sent to Nostr.' }
    else
      render json: { status: 'error', message: @bookmark.errors.full_messages.join(', ') }, status: :unprocessable_entity
    end
  end

  private

  def bookmark_params
    params.require(:bookmark).permit(:title, :url, :description, :event_id, :user_id)
  end
end
