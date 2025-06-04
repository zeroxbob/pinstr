require 'rails_helper'

RSpec.describe UrlService do
  describe '.normalize' do
    it 'adds https protocol if missing' do
      expect(UrlService.normalize('example.com')).to eq('https://example.com')
    end
    
    it 'preserves existing protocol' do
      expect(UrlService.normalize('http://example.com')).to eq('http://example.com')
    end
    
    it 'lowercases the host' do
      expect(UrlService.normalize('EXAMPLE.com')).to eq('https://example.com')
    end
    
    it 'removes trailing slashes' do
      expect(UrlService.normalize('example.com/')).to eq('https://example.com')
      expect(UrlService.normalize('example.com/path/')).to eq('https://example.com/path')
    end
    
    it 'preserves path' do
      expect(UrlService.normalize('example.com/some/path')).to eq('https://example.com/some/path')
    end
    
    it 'preserves query parameters by default' do
      expect(UrlService.normalize('example.com/path?q=test')).to eq('https://example.com/path?q=test')
    end
    
    it 'strips query parameters when requested' do
      expect(UrlService.normalize('example.com/path?q=test', strip_params: true)).to eq('https://example.com/path')
    end
    
    it 'strips www by default' do
      expect(UrlService.normalize('www.example.com')).to eq('https://example.com')
    end
    
    it 'preserves www when requested' do
      expect(UrlService.normalize('www.example.com', strip_www: false)).to eq('https://www.example.com')
    end
    
    it 'preserves fragments' do
      expect(UrlService.normalize('example.com/path#section')).to eq('https://example.com/path#section')
    end
    
    it 'preserves non-standard ports' do
      expect(UrlService.normalize('example.com:8080/path')).to eq('https://example.com:8080/path')
    end
  end
  
  describe '.valid?' do
    it 'returns true for valid URLs' do
      expect(UrlService.valid?('https://example.com')).to be true
      expect(UrlService.valid?('http://example.com/path')).to be true
      expect(UrlService.valid?('example.com')).to be true
    end
    
    it 'returns false for invalid URLs' do
      expect(UrlService.valid?('')).to be false
      expect(UrlService.valid?(nil)).to be false
      expect(UrlService.valid?('not a url')).to be false
      expect(UrlService.valid?('http://')).to be false
    end
    
    it 'returns false for malformed protocol URLs' do
      expect(UrlService.valid?('https://http')).to be false
      expect(UrlService.valid?('http://https')).to be false
      expect(UrlService.valid?('ftp://http')).to be false
      expect(UrlService.valid?('https://ftp')).to be false
    end
    
    it 'returns false for URLs with invalid host patterns' do
      expect(UrlService.valid?('https://')).to be false
      expect(UrlService.valid?('https://.')).to be false
      expect(UrlService.valid?('https://..')).to be false
      expect(UrlService.valid?('https://...')).to be false
      expect(UrlService.valid?('https://com')).to be false
    end
  end
  
  describe '.equivalent?' do
    it 'returns true for identical URLs' do
      expect(UrlService.equivalent?('https://example.com', 'https://example.com')).to be true
    end
    
    it 'returns true for URLs that differ only in protocol' do
      expect(UrlService.equivalent?('http://example.com', 'https://example.com')).to be true
    end
    
    it 'returns true for URLs that differ in casing' do
      expect(UrlService.equivalent?('https://EXAMPLE.com', 'https://example.com')).to be true
    end
    
    it 'returns true for URLs that differ in trailing slashes' do
      expect(UrlService.equivalent?('https://example.com/', 'https://example.com')).to be true
    end
    
    it 'returns true for URLs that differ in www prefix' do
      expect(UrlService.equivalent?('https://www.example.com', 'https://example.com')).to be true
    end
    
    it 'returns true for URLs that differ in query params when not in strict mode' do
      expect(UrlService.equivalent?('https://example.com/path?q=test', 'https://example.com/path')).to be true
    end
    
    it 'returns false for URLs that differ in query params when in strict mode' do
      expect(UrlService.equivalent?('https://example.com/path?q=test', 'https://example.com/path', strict: true)).to be false
    end
    
    it 'returns false for different URLs' do
      expect(UrlService.equivalent?('https://example.com', 'https://example.org')).to be false
      expect(UrlService.equivalent?('https://example.com/path1', 'https://example.com/path2')).to be false
    end
  end
end
