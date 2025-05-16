require 'uri'

class UrlService
  # Normalizes a URL to ensure consistent format
  # - Adds https:// if no protocol is provided
  # - Removes trailing slashes
  # - Removes query parameters if strip_params is true
  # - Lowercases the host
  # - Removes www. prefix if strip_www is true
  def self.normalize(url, strip_params: false, strip_www: true)
    return nil if url.blank?
    
    # Add protocol if missing
    unless url.match?(/\A[a-z][a-z0-9+\-.]*:/i)
      url = "https://#{url}"
    end
    
    begin
      uri = URI.parse(url)
      
      # Ensure the URI has a host
      return url unless uri.host
      
      # Build normalized URL
      normalized = String.new.force_encoding('UTF-8')
      normalized << (uri.scheme || 'https') << '://'
      
      # Strip www if requested
      host = uri.host.downcase
      host = host.sub(/\Awww\./i, '') if strip_www && host.start_with?('www.')
      normalized << host
      
      # Add port if non-standard
      if uri.port && uri.port != uri.default_port
        normalized << ":#{uri.port}"
      end
      
      # Add path (remove trailing slash)
      path = uri.path
      path = '/' if path.blank? || path.empty?
      path = path.chomp('/') unless path == '/'
      normalized << path
      
      # Add query params if not stripping
      normalized << "?#{uri.query}" if uri.query.present? && !strip_params
      
      # Add fragment
      normalized << "##{uri.fragment}" if uri.fragment.present?
      
      normalized.force_encoding('UTF-8')
    rescue URI::InvalidURIError
      # If normalization fails, return the original URL
      url
    end
  end
  
  # Validates if a string is a valid URL
  def self.valid?(url)
    return false if url.blank?
    
    # Try to normalize first
    normalized = normalize(url)
    
    begin
      uri = URI.parse(normalized)
      # Check if it has a scheme and host
      return false unless uri.scheme && uri.host
      return true if uri.scheme =~ /\Ahttps?\z/i
      false
    rescue URI::InvalidURIError
      false
    end
  end
  
  # Determines if two URLs are equivalent after normalization
  def self.equivalent?(url1, url2, strict: false)
    return false if url1.blank? || url2.blank?
    
    # When strict is false, we strip params for comparison
    norm1 = normalize(url1, strip_params: !strict, strip_www: true).downcase
    norm2 = normalize(url2, strip_params: !strict, strip_www: true).downcase
    
    # Replace the scheme part for comparison to ignore protocol differences
    norm1 = norm1.sub(/\Ahttps?:\/\//i, 'https://')
    norm2 = norm2.sub(/\Ahttps?:\/\//i, 'https://')
    
    norm1 == norm2
  end
end
