module NostrHelper
  # Build a NIP-B0 web bookmark event
  def self.build_web_bookmark_event(pubkey:, url:, title:, description: nil, created_at: nil)
    created_at ||= Time.now.to_i
    description ||= ""
    
    # Extract d-tag (URL without scheme, query params, or hash fragment)
    d_tag = url.sub(/\Ahttps?:\/\//i, '').split('?')[0].split('#')[0]
    
    # Build tags array
    tags = [
      ["d", d_tag],  # Required
      ["published_at", created_at.to_s],  # Optional
      ["title", title]  # Optional
    ]
    
    # Add hashtags from description
    description.scan(/(?:\s|^)#([\w\d]+)/) do |match|
      tags << ["t", match[0]] if match[0].present?
    end
    
    # Create the event data
    {
      kind: 39701,  # NIP-B0 web bookmark
      pubkey: pubkey,
      created_at: created_at,
      tags: tags,
      content: description
    }
  end
  
  # Extract metadata from a NIP-B0 event
  def self.extract_metadata_from_event(event)
    return {} unless event.is_a?(Hash)
    
    metadata = {
      event_id: event["id"],
      published_at: nil,
      title: nil,
      hashtags: []
    }
    
    # Set content as description
    metadata[:description] = event["content"]
    
    # Extract data from tags
    if event["tags"].is_a?(Array)
      event["tags"].each do |tag|
        next unless tag.is_a?(Array)
        
        case tag[0]
        when "d"
          # d tag contains the URL identifier
          metadata[:d_tag] = tag[1] if tag[1].present?
        when "published_at"
          # Original publication timestamp
          metadata[:published_at] = tag[1].to_i if tag[1].present?
        when "title"
          # Title of the bookmark
          metadata[:title] = tag[1] if tag[1].present?
        when "t"
          # Hashtag/topic
          metadata[:hashtags] << tag[1] if tag[1].present?
        end
      end
    end
    
    metadata
  end
  
  # Verify if an event follows the NIP-B0 format
  def self.verify_nipb0_format(event)
    return false unless event.is_a?(Hash)
    
    # Check required fields
    return false unless event["kind"] == 39701
    return false unless event["pubkey"].present?
    return false unless event["id"].present?
    return false unless event["created_at"].present?
    
    # Check for required d tag
    has_d_tag = false
    if event["tags"].is_a?(Array)
      event["tags"].each do |tag|
        if tag.is_a?(Array) && tag.length >= 2 && tag[0] == "d" && tag[1].present?
          has_d_tag = true
          break
        end
      end
    end
    
    has_d_tag
  end
end