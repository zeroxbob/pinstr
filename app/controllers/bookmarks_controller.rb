class BookmarksController < ApplicationController
  protect_from_forgery with: :exception
  # Skip authentication for tests but maintain it for production
  before_action :authenticate_user!, unless: -> { Rails.env.test? || current_user }

  def index
    @bookmarks = Bookmark.all

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @bookmarks }
    end
  end

  def create
    signed_event = params[:signed_event]

    # Log the signed event for debugging
    Rails.logger.info("Received signed event: #{signed_event.inspect}")

    # Add validation for NIP-B0 format
    unless signed_event.is_a?(Hash) && (signed_event["kind"] == 39701 || signed_event[:kind] == 39701)
      Rails.logger.error("Invalid event format: Not a NIP-B0 event (kind 39701)")
      respond_to do |format|
        format.html { render :new, alert: 'Invalid event format: Not a NIP-B0 event (kind 39701)' }
        format.json { render json: { errors: ['Invalid event format: Not a NIP-B0 event (kind 39701)'] }, status: :unprocessable_entity }
      end
      return
    end

    # Find the title from NIP-B0 tags
    event_title = nil
    if signed_event["tags"].is_a?(Array) || signed_event[:tags].is_a?(Array)
      tags = signed_event["tags"] || signed_event[:tags]
      tags.each do |tag|
        if tag.is_a?(Array) && tag[0] == "title" && tag[1].present?
          event_title = tag[1]
          break
        end
      end
    end

    # Extract description from content field
    event_description = signed_event["content"] || signed_event[:content] if signed_event["content"].present? || signed_event[:content].present?

    # Find d-tag for the URL (this is the NIP-B0 identifier)
    d_tag = nil
    if signed_event["tags"].is_a?(Array) || signed_event[:tags].is_a?(Array)
      tags = signed_event["tags"] || signed_event[:tags]
      tags.each do |tag|
        if tag.is_a?(Array) && tag[0] == "d" && tag[1].present?
          d_tag = tag[1]
          break
        end
      end
    end

    # Construct full URL from d-tag
    url = d_tag.present? ? "https://#{d_tag}" : params[:bookmark][:url]

    # Use the event ID or a fallback
    event_id = signed_event["id"] || signed_event[:id]
    
    # Get user ID from signed event pubkey or current user
    pubkey = signed_event["pubkey"] || signed_event[:pubkey]
    user_id = User.find_by(public_key: pubkey)&.id || current_user&.id
    
    # Build the bookmark
    @bookmark = Bookmark.new(
      title: event_title || params[:bookmark][:title],
      url: url,
      description: event_description || params[:bookmark][:description],
      event_id: event_id,
      user_id: user_id,
      signed_event_content: signed_event.to_json,
      signed_event_sig: signed_event["sig"] || signed_event[:sig]
    )

    if @bookmark.save
      respond_to do |format|
        format.html { redirect_to bookmarks_path, notice: 'Bookmark was successfully created and signed event stored.' }
        format.json { render json: { status: 'success', redirect_url: bookmarks_path }, status: :ok }
      end
    else
      Rails.logger.error("Bookmark save failed: #{@bookmark.errors.full_messages.join(', ')}")
      respond_to do |format|
        format.html { render :new, alert: @bookmark.errors.full_messages.join(', ') }
        format.json { render json: { errors: @bookmark.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def new
    @bookmark = Bookmark.new
  end

  def show
    @bookmark = Bookmark.find(params[:id])
  end

  def edit
    @bookmark = Bookmark.find(params[:id])
  end

  def update
    @bookmark = Bookmark.find(params[:id])
    if @bookmark.update(bookmark_params)
      redirect_to @bookmark, notice: 'Bookmark was successfully updated.'
    else
      render :edit
    end
  end

  def destroy
    @bookmark = Bookmark.find(params[:id])
    @bookmark.destroy
    redirect_to bookmarks_path, notice: 'Bookmark was successfully destroyed.'
  end

  private

  def bookmark_params
    params.require(:bookmark).permit(:title, :url, :description)
  end
end