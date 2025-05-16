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
    
    # Special case for URLs with non-standard ports but no protocol
    if url.match?(/\A[^:\/]+:\d+/) && !url.match?(/\A[a-z][a-z0-9+\-.]*:\/\//i)
      # Handle special cases like "example.com:8080/path"
      if url =~ /\A([^:]+):(\d+)(\/.*)?\z/
        host = $1
        port = $2
        path = $3 || ''
        url = "https://#{host}:#{port}#{path}"
      end
    elsif !url.match?(/\A[a-z][a-z0-9+\-.]*:/i)
      # Add protocol if missing for other URLs
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
      if path.blank? || path == '/'
        # Don't add anything for the path
      else
        # Remove trailing slash if present
        path = path.chomp('/')
        normalized << path
      end
      
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
      return false unless uri.scheme && uri.host && !uri.host.empty?
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
    # Remove trailing slashes from both URLs for comparison
    norm1 = normalize(url1, strip_params: !strict, strip_www: true).downcase
    norm2 = normalize(url2, strip_params: !strict, strip_www: true).downcase
    
    # Replace the scheme part for comparison to ignore protocol differences
    norm1 = norm1.sub(/\Ahttps?:\/\//i, 'https://')
    norm2 = norm2.sub(/\Ahttps?:\/\//i, 'https://')
    
    # Remove trailing slashes for comparison
    norm1 = norm1.chomp('/')
    norm2 = norm2.chomp('/')
    
    norm1 == norm2
  end
end