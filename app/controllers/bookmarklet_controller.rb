class BookmarkletController < ApplicationController
  # Skip CSRF protection for the bookmarklet form
  # This is because the bookmarklet is loaded from another domain
  skip_before_action :verify_authenticity_token, only: [:create]
  before_action :authenticate_user!, unless: -> { Rails.env.test? || current_user }

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
  
  def success
    # This action is for showing a success message after bookmark creation
    # Detect if opened in a popup window
    @in_popup = params[:popup].present?
    
    render layout: @in_popup ? 'bookmarklet' : 'application'
  end

  def create
    # ENHANCED LOGGING FOR DEBUGGING
    Rails.logger.info "=" * 80
    Rails.logger.info "BOOKMARKLET CREATE ACTION CALLED"
    Rails.logger.info "=" * 80
    Rails.logger.info "Request format: #{request.format.inspect}"
    Rails.logger.info "Content-Type: #{request.content_type}"
    Rails.logger.info "Request method: #{request.method}"
    Rails.logger.info "Raw params keys: #{params.keys.inspect}"
    Rails.logger.info "Has signed_event param: #{params[:signed_event].present?}"
    Rails.logger.info "Has bookmark param: #{params[:bookmark].present?}"
    Rails.logger.info "Has direct_submission param: #{params[:direct_submission].present?}"
    Rails.logger.info "Has popup param: #{params[:popup].present?}"
    
    if params[:signed_event].present?
      Rails.logger.info "SIGNED EVENT DETAILS:"
      Rails.logger.info "  Type: #{params[:signed_event].class}"
      Rails.logger.info "  Content: #{params[:signed_event].inspect}"
      
      if params[:signed_event].is_a?(ActionController::Parameters) || params[:signed_event].is_a?(Hash)
        event_hash = params[:signed_event].is_a?(ActionController::Parameters) ? params[:signed_event].to_unsafe_h : params[:signed_event]
        Rails.logger.info "  Event ID: #{event_hash['id'] || event_hash[:id]}"
        Rails.logger.info "  Event Kind: #{event_hash['kind'] || event_hash[:kind]}"
        Rails.logger.info "  Event Pubkey: #{event_hash['pubkey'] || event_hash[:pubkey]}"
        Rails.logger.info "  Event Signature: #{event_hash['sig'] || event_hash[:sig]}"
      end
    else
      Rails.logger.info "NO SIGNED EVENT RECEIVED"
    end
    
    if params[:bookmark].present?
      Rails.logger.info "BOOKMARK PARAMS:"
      Rails.logger.info "  Title: #{params[:bookmark][:title]}"
      Rails.logger.info "  URL: #{params[:bookmark][:url]}"
      Rails.logger.info "  Description: #{params[:bookmark][:description]}"
    end
    
    Rails.logger.info "=" * 80
    
    if request.content_type&.include?('application/json')
      # Handle JSON requests, typically from the JavaScript Stimulus controller
      Rails.logger.info "PROCESSING AS JSON REQUEST"
      create_from_json
    else
      # Handle regular form submissions (fallback)
      Rails.logger.info "PROCESSING AS FORM REQUEST"
      create_from_form
    end
  end

  private

  def create_from_json
    # Extract data from the JSON request
    bookmark_params = params[:bookmark]
    signed_event = params[:signed_event]
    is_popup = params[:popup]
    
    Rails.logger.info("JSON REQUEST PROCESSING:")
    Rails.logger.info("  Bookmark params present: #{bookmark_params.present?}")
    Rails.logger.info("  Signed event present: #{signed_event.present?}")
    Rails.logger.info("  Is popup: #{is_popup}")
    
    # Validate presence of required fields
    unless bookmark_params && bookmark_params[:url] && bookmark_params[:title]
      Rails.logger.error("VALIDATION FAILED: Missing required bookmark parameters")
      render json: { errors: ["Missing required bookmark parameters"] }, status: :unprocessable_entity
      return
    end
    
    # Process based on whether we have a signed event
    if signed_event.present?
      Rails.logger.info("PROCESSING WITH SIGNED EVENT")
      process_with_signed_event(signed_event, bookmark_params, is_popup)
    else
      Rails.logger.info("PROCESSING WITHOUT SIGNED EVENT")
      process_without_signed_event(bookmark_params, is_popup)
    end
  end
  
  def create_from_form
    # This is the fallback method when JavaScript is disabled or the Nostr signing fails
    Rails.logger.info("Processing direct form submission")
    
    # Generate a random event ID if not using Nostr
    event_id = "manual-#{SecureRandom.hex(16)}"
    
    @bookmark = Bookmark.new(
      title: params[:bookmark][:title],
      url: params[:bookmark][:url],
      description: params[:bookmark][:description],
      event_id: event_id,
      user_id: current_user&.id
    )
    
    if @bookmark.save
      Rails.logger.info("FORM SUBMISSION: Bookmark saved successfully without Nostr")
      if params[:popup]
        # Add nostr_signed parameter to indicate no Nostr signing
        redirect_to success_bookmarklet_path(popup: true, nostr_signed: false)
      else
        redirect_to bookmarks_path, notice: 'Bookmark was successfully created.'
      end
    else
      Rails.logger.error("FORM SUBMISSION: Bookmark save failed: #{@bookmark.errors.full_messages}")
      render :add, alert: @bookmark.errors.full_messages.join(', ')
    end
  end
  
  def process_with_signed_event(signed_event, bookmark_params, is_popup)
    Rails.logger.info("PROCESSING SIGNED EVENT:")
    Rails.logger.info("  Raw signed_event: #{signed_event.inspect}")
    
    # Convert ActionController::Parameters to a regular hash with symbolized keys if needed
    signed_event = signed_event.to_unsafe_h.symbolize_keys if signed_event.is_a?(ActionController::Parameters)
    Rails.logger.info("  Converted signed_event: #{signed_event.inspect}")
    
    # Ensure kind is an integer
    if signed_event[:kind].is_a?(String)
      Rails.logger.info("  Converting kind from string to integer")
      signed_event[:kind] = signed_event[:kind].to_i
    end
    
    Rails.logger.info("  Event kind: #{signed_event[:kind]} (#{signed_event[:kind].class})")
    
    # Validate it's a NIP-B0 bookmark event
    unless signed_event[:kind] == 39701
      Rails.logger.error("VALIDATION FAILED: Invalid event kind: #{signed_event[:kind]} - expected 39701")
      render json: { errors: ["Invalid event kind: #{signed_event[:kind]} - expected 39701 (NIP-B0)"] }, status: :unprocessable_entity
      return
    end
    
    # Get essential data from the event
    event_id = signed_event[:id]
    pubkey = signed_event[:pubkey]
    sig = signed_event[:sig]
    
    Rails.logger.info("  Event ID: #{event_id}")
    Rails.logger.info("  Pubkey: #{pubkey}")
    Rails.logger.info("  Signature: #{sig}")
    
    # Validate required fields
    unless event_id && pubkey && sig
      Rails.logger.error("VALIDATION FAILED: Missing required event fields")
      Rails.logger.error("  Missing event_id: #{event_id.blank?}")
      Rails.logger.error("  Missing pubkey: #{pubkey.blank?}")
      Rails.logger.error("  Missing sig: #{sig.blank?}")
      render json: { errors: ["Missing required event fields: id, pubkey, or sig"] }, status: :unprocessable_entity
      return
    end
    
    # Find user by public key or use current user
    user = User.find_by(public_key: pubkey)
    user_id = user&.id || current_user&.id
    Rails.logger.info("  Found user: #{user.present?} (ID: #{user_id})")
    
    # Extract additional data from the event
    content = signed_event[:content]
    
    # Extract URL from d-tag if available
    url = bookmark_params[:url]
    d_tag = nil
    
    if signed_event[:tags].is_a?(Array)
      signed_event[:tags].each do |tag|
        if tag.is_a?(Array) && tag[0] == "d" && tag[1].present?
          d_tag = tag[1]
          break
        end
      end
      
      # Use d-tag to construct URL if available
      url = "https://#{d_tag}" if d_tag.present?
    end
    
    # Extract title from title tag if available
    title = bookmark_params[:title]
    signed_event[:tags].each do |tag|
      if tag.is_a?(Array) && tag[0] == "title" && tag[1].present?
        title = tag[1]
        break
      end
    end
    
    Rails.logger.info("  Final title: #{title}")
    Rails.logger.info("  Final URL: #{url}")
    Rails.logger.info("  Final description: #{content || bookmark_params[:description]}")
    
    # Create the bookmark
    @bookmark = Bookmark.new(
      title: title,
      url: url,
      description: content || bookmark_params[:description],
      event_id: event_id,
      user_id: user_id,
      signed_event_content: signed_event.to_json,
      signed_event_sig: sig
    )
    
    Rails.logger.info("ATTEMPTING TO SAVE BOOKMARK WITH SIGNED EVENT:")
    Rails.logger.info("  Bookmark attributes: #{@bookmark.attributes}")
    
    if @bookmark.save
      Rails.logger.info("✅ SUCCESS: Bookmark saved successfully with signed event!")
      Rails.logger.info("  Bookmark ID: #{@bookmark.id}")
      Rails.logger.info("  Has signed_event_content: #{@bookmark.signed_event_content.present?}")
      Rails.logger.info("  Has signed_event_sig: #{@bookmark.signed_event_sig.present?}")
      
      if is_popup
        # Return success with a URL to redirect to
        render json: { 
          status: 'success', 
          message: 'Bookmark created successfully with Nostr event',
          redirect_url: success_bookmarklet_path(popup: true, nostr_signed: true),
          bookmark_id: @bookmark.id,
          is_popup: is_popup
        }, status: :ok
      else
        render json: { 
          status: 'success', 
          message: 'Bookmark created successfully with Nostr event',
          redirect_url: bookmarks_path,
          bookmark_id: @bookmark.id
        }, status: :ok
      end
    else
      Rails.logger.error("❌ FAILURE: Bookmark save failed with errors:")
      @bookmark.errors.full_messages.each do |error|
        Rails.logger.error("  - #{error}")
      end
      render json: { errors: @bookmark.errors.full_messages }, status: :unprocessable_entity
    end
  end
  
  def process_without_signed_event(bookmark_params, is_popup)
    Rails.logger.info("Processing submission without signed Nostr event")
    
    # Generate a random event ID
    event_id = "manual-#{SecureRandom.hex(16)}"
    
    # Create the bookmark
    @bookmark = Bookmark.new(
      title: bookmark_params[:title],
      url: bookmark_params[:url],
      description: bookmark_params[:description],
      event_id: event_id,
      user_id: current_user&.id
    )
    
    if @bookmark.save
      Rails.logger.info("Bookmark saved successfully without signed event")
      if is_popup
        render json: { 
          status: 'success', 
          message: 'Bookmark created successfully without Nostr integration',
          redirect_url: success_bookmarklet_path(popup: true, nostr_signed: false),
          bookmark_id: @bookmark.id
        }, status: :ok
      else
        render json: { 
          status: 'success', 
          message: 'Bookmark created successfully without Nostr integration',
          redirect_url: bookmarks_path,
          bookmark_id: @bookmark.id
        }, status: :ok
      end
    else
      Rails.logger.info("Bookmark save failed: #{@bookmark.errors.full_messages.join(", ")}")
      render json: { errors: @bookmark.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def bookmark_params
    params.require(:bookmark).permit(:title, :url, :description)
  end
end
