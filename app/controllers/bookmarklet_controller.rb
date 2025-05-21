class BookmarkletController < ApplicationController
  # Skip CSRF protection for the bookmarklet form
  # This is because the bookmarklet is loaded from another domain
  skip_before_action :verify_authenticity_token, only: [:create]
  before_action :authenticate_user!, unless: -> { Rails.env.test? || current_user }

  def instructions
    # Show bookmarklet installation instructions
  end

  def add
    @bookmark = Bookmark.new(
      url: params[:url],
      title: params[:title],
      description: params[:description]
    )
    
    # Detect if opened in a popup window
    @in_popup = params[:popup].present?
    
    render layout: @in_popup ? 'bookmarklet' : 'application'
  end

  def create
    # Check if we received a signed event
    if params[:signed_event].present?
      create_with_signed_event
    else
      create_without_signed_event
    end
  end

  private

  def create_with_signed_event
    # Get the signed event from params and convert to hash if it's ActionController::Parameters
    signed_event_params = params[:signed_event]
    
    # Convert ActionController::Parameters to a regular hash with symbolized keys
    signed_event = if signed_event_params.is_a?(ActionController::Parameters)
      signed_event_params.to_unsafe_h.symbolize_keys
    else
      signed_event_params
    end
    
    if signed_event.is_a?(Hash)
      # Ensure kind is an integer
      if signed_event[:kind].is_a?(String) && signed_event[:kind].to_i == 39701
        signed_event[:kind] = 39701
      end
    end

    # Add validation for NIP-B0 format
    unless signed_event.is_a?(Hash) && signed_event[:kind] == 39701
      error_msg = "Invalid event format: Not a NIP-B0 event (kind 39701)"
      
      respond_to do |format|
        format.html { render :add, alert: error_msg }
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
          break
        end
      end
    end

    # Extract description from content field
    event_description = signed_event[:content] if signed_event[:content].present?

    # Find d-tag for the URL (this is the NIP-B0 identifier)
    d_tag = nil
    if signed_event[:tags].is_a?(Array)
      tags = signed_event[:tags]
      tags.each do |tag|
        if tag.is_a?(Array) && tag[0] == "d" && tag[1].present?
          d_tag = tag[1]
          break
        end
      end
    end

    # Construct full URL from d-tag
    url = d_tag.present? ? "https://#{d_tag}" : params[:bookmark][:url]

    # Use the event ID
    event_id = signed_event[:id]
    
    # Get user ID from signed event pubkey or current user
    pubkey = signed_event[:pubkey]
    user = User.find_by(public_key: pubkey)
    user_id = user&.id || current_user&.id
    
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

    save_bookmark
  end

  def create_without_signed_event
    # If no signed event was provided, create a bookmark without Nostr integration
    # This is useful for users who don't have a Nostr extension installed
    
    # Generate a random event ID if not using Nostr
    event_id = "manual-#{SecureRandom.hex(16)}"
    
    @bookmark = Bookmark.new(
      title: params[:bookmark][:title],
      url: params[:bookmark][:url],
      description: params[:bookmark][:description],
      event_id: event_id,
      user_id: current_user&.id
    )
    
    save_bookmark
  end

  def save_bookmark
    if @bookmark.save
      respond_to do |format|
        format.html do 
          if params[:popup]
            # If it's a popup, show success and provide close button
            render :success, layout: 'bookmarklet'
          else
            redirect_to bookmarks_path, notice: 'Bookmark was successfully created.'
          end
        end
        format.json { render json: { status: 'success', redirect_url: bookmarks_path }, status: :ok }
      end
    else
      respond_to do |format|
        format.html { render :add, alert: @bookmark.errors.full_messages.join(', ') }
        format.json { render json: { errors: @bookmark.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def bookmark_params
    params.require(:bookmark).permit(:title, :url, :description)
  end
end
