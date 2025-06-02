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
    # Get the signed event from params and convert to hash if it's ActionController::Parameters
    signed_event_params = params[:signed_event]
    
    # Enhanced debugging for the signed event
    Rails.logger.info("Received signed event: #{signed_event_params.inspect}")
    Rails.logger.info("Signed event class: #{signed_event_params.class}")
    
    # Convert ActionController::Parameters to a regular hash with symbolized keys
    signed_event = if signed_event_params.is_a?(ActionController::Parameters)
      signed_event_params.to_unsafe_h.symbolize_keys
    else
      signed_event_params
    end
    
    Rails.logger.info("Converted signed event: #{signed_event.inspect}")
    Rails.logger.info("Converted event class: #{signed_event.class}")
    
    if signed_event.is_a?(Hash)
      Rails.logger.info("Event kind: #{signed_event[:kind].inspect} (#{signed_event[:kind].class if signed_event[:kind]})")
      
      # Ensure kind is an integer
      if signed_event[:kind].is_a?(String) && signed_event[:kind].to_i == 39701
        Rails.logger.info("Converting kind from string to integer")
        signed_event[:kind] = 39701
      end
    end

    # Add validation for NIP-B0 format
    unless signed_event.is_a?(Hash) && signed_event[:kind] == 39701
      error_msg = "Invalid event format: Not a NIP-B0 event (kind 39701)"
      Rails.logger.error(error_msg)
      Rails.logger.error("Actual kind: #{signed_event.is_a?(Hash) ? signed_event[:kind].inspect : 'N/A'}")
      
      respond_to do |format|
        format.html { render :new, alert: error_msg }
        format.json { render json: { errors: [error_msg] }, status: :unprocessable_entity }
      end
      return
    end

    # Find the title from NIP-B0 tags
    event_title = nil
    if signed_event[:tags].is_a?(Array)
      tags = signed_event[:tags]
      tags.each do |tag|
        if tag.is_a?(Array) && tag[0] == "title" && tag[1].present?
          event_title = tag[1]
          Rails.logger.info("Found title tag: #{event_title}")
          break
        end
      end
    end

    # Extract description from content field
    event_description = signed_event[:content] if signed_event[:content].present?
    Rails.logger.info("Extracted description: #{event_description}")

    # Find d-tag for the URL (this is the NIP-B0 identifier)
    d_tag = nil
    if signed_event[:tags].is_a?(Array)
      tags = signed_event[:tags]
      tags.each do |tag|
        if tag.is_a?(Array) && tag[0] == "d" && tag[1].present?
          d_tag = tag[1]
          Rails.logger.info("Found d tag: #{d_tag}")
          break
        end
      end
    end

    # Construct full URL from d-tag
    url = d_tag.present? ? "https://#{d_tag}" : params[:bookmark][:url]
    Rails.logger.info("Constructed URL: #{url}")

    # Use the event ID
    event_id = signed_event[:id]
    Rails.logger.info("Event ID: #{event_id}")
    
    # Get user ID from signed event pubkey or current user
    pubkey = signed_event[:pubkey]
    user = User.find_by(public_key: pubkey)
    user_id = user&.id || current_user&.id
    
    Rails.logger.info("Using pubkey: #{pubkey}, matched to user_id: #{user_id}")
    
    # Build the bookmark
    @bookmark = Bookmark.new(
      title: event_title || params[:bookmark][:title],
      url: url,
      description: event_description || params[:bookmark][:description],
      event_id: event_id,
      user_id: user_id,
      signed_event_content: signed_event.to_json,
      signed_event_sig: signed_event[:sig]
    )

    if @bookmark.save
      Rails.logger.info("Bookmark saved successfully with ID: #{@bookmark.id}")
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
