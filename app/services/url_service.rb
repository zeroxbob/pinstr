require 'uri'
require 'active_model'

class UrlService
  # Normalizes a URL to ensure consistent format
  # - Adds https:// if no protocol is provided
  # - Removes trailing slashes
  # - Removes query parameters if strip_params is true
  # - Lowercases the host
  # - Removes www. prefix if strip_www is true
  def self.normalize(url, strip_params: false, strip_www: true)
    return nil if url.blank?
    
    # Handle non-standard port URL special case
    url = prepare_url_with_port(url)
    
    begin
      uri = URI.parse(url)
      
      # Ensure the URI has a host
      return url unless uri.host
      
      # Build normalized URL
      normalized = String.new.force_encoding('UTF-8')
      normalized << (uri.scheme || 'https') << '://'
      
      # Strip www if requested and apply lowercase to host
      host = uri.host.downcase
      host = host.sub(/\Awww\./i, '') if strip_www && host.start_with?('www.')
      normalized << host
      
      # Add port if non-standard
      if uri.port && uri.port != uri.default_port
        normalized << ":#{uri.port}"
      end
      
      # Add path (remove trailing slash unless it's just /)
      path = uri.path
      if path.blank? || path.empty? || path == '/'
        # Nothing to add for empty path or just root
      else
        # Remove trailing slash for non-root paths
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
  
  # Canonicalizes a URL by normalizing and standardizing it
  # - Converts http:// to https://
  # - Always removes www prefix
  # - Removes trailing slashes
  # - Removes query parameters unless keep_params is true
  def self.canonicalize(url, keep_params: false)
    return nil if url.blank?
    
    # First normalize the URL
    normalized = normalize(url, strip_params: !keep_params, strip_www: true)
    
    # Convert http to https
    canonical = normalized.sub(/\Ahttp:/i, 'https:')
    
    canonical
  end
  
  # Validates if a string is a valid URL using Rails' built-in validation
  def self.valid?(url)
    return false if url.blank?
    
    # Create a temporary model to use Rails' URL validation
    validator_class = Class.new do
      include ActiveModel::Model
      include ActiveModel::Attributes
      include ActiveModel::Validations
      
      attribute :url, :string
      validates :url, format: { 
        with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), 
        message: 'is not a valid URL' 
      }
      
      # Additional custom validation
      validate :validate_url_structure
      
      private
      
      def validate_url_structure
        return if url.blank?
        
        begin
          uri = URI.parse(url)
          
          # Must be HTTP or HTTPS
          unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
            errors.add(:url, 'must use http or https protocol')
            return
          end
          
          # Must have a valid host
          unless uri.host&.present?
            errors.add(:url, 'must have a valid host')
            return
          end
          
          host = uri.host.downcase.strip
          
          # Reject obviously invalid hosts
          if %w[http https ftp].include?(host)
            errors.add(:url, 'host cannot be a protocol name')
            return
          end
          
          if host.match?(/\A\.+\z/)
            errors.add(:url, 'host cannot be only dots')
            return
          end
          
          # Require domain structure (except localhost) or valid IP
          ip_pattern = /\A(\d{1,3}\.){3}\d{1,3}\z/
          unless host == 'localhost' || host.include?('.') || host.match?(ip_pattern)
            errors.add(:url, 'host must be a valid domain or IP address')
          end
          
        rescue URI::InvalidURIError
          errors.add(:url, 'is malformed')
        end
      end
    end
    
    # Try to normalize first, then validate
    normalized = normalize(url)
    validator = validator_class.new(url: normalized)
    validator.valid?
  end
  
  # Determines if two URLs are equivalent after canonicalization
  def self.equivalent?(url1, url2, strict: false)
    return false if url1.blank? || url2.blank?
    
    # For URL equivalence, we compare after removing trailing slashes
    # and standardizing the schemes
    a = standardize_for_comparison(url1, keep_params: strict)
    b = standardize_for_comparison(url2, keep_params: strict)
    
    a == b
  end
  
  # Standardizes a URL for comparison
  def self.standardize_for_comparison(url, keep_params: false)
    # First normalize through our URL service
    standard = canonicalize(url, keep_params: keep_params)
    
    # Remove any trailing slash explicitly for comparison
    standard = standard.chomp('/')
    
    # Lowercase everything
    standard.downcase
  end
  
  # Helper method to prepare URLs with non-standard ports
  def self.prepare_url_with_port(url)
    # Handle URLs with non-standard ports but no protocol
    # Example: example.com:8080/path
    if url.match?(/\A([^:\/]+):(\d+)/) && !url.match?(/\A[a-z][a-z0-9+\-.]*:\/\//i)
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
    
    url
  end
end