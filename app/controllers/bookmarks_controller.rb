class BookmarksController < ApplicationController
  protect_from_forgery with: :exception

  def index
    @bookmarks = Bookmark.all

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @bookmarks }
    end
  end

  def create
    signed_event = params[:signed_event]

    bookmark_params = {
      title: signed_event['content'],
      url: request.referer || 'unknown',
      description: '',
      event_id: signed_event['id'],
      user_id: User.find_by(public_key: signed_event['pubkey'])&.id,
      signed_event_content: signed_event.to_json,  # Save entire JSON
      signed_event_sig: signed_event['sig']        # Save signature
    }

    @bookmark = Bookmark.new(bookmark_params)

    if @bookmark.save
      redirect_to bookmarks_path, notice: 'Bookmark was successfully created and signed event stored.'
    else
      render :new, alert: @bookmark.errors.full_messages.join(', ')
    end
  end

  def new
    @bookmark = Bookmark.new
  end
end
