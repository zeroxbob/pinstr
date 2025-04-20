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

    @bookmark = Bookmark.new(bookmark_params.merge(signed_event_content: signed_event.to_json, signed_event_sig: signed_event['sig']))

    if @bookmark.save
      respond_to do |format|
        format.html { redirect_to bookmarks_path, notice: 'Bookmark was successfully created and signed event stored.' }
        format.json { render json: { status: 'success' }, status: :ok }
      end
    else
      respond_to do |format|
        format.html { render :new, alert: @bookmark.errors.full_messages.join(', ') }
        format.json { render json: { errors: @bookmark.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def new
    @bookmark = Bookmark.new
  end

  private

  def bookmark_params
    params.require(:bookmark).permit(:title, :url, :description).merge(
      event_id: params[:signed_event][:id],
      user_id: User.find_by(public_key: params[:signed_event][:pubkey])&.id
    )
  end
end
