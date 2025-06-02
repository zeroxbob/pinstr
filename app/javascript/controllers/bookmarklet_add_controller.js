import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["status", "form", "title", "url", "description", "submitButton", "formError"]
  
  connect() {
    console.log("Bookmarklet add controller connected")
    
    // Initialize state
    this.formSubmitting = false
    
    // Check if we're in a popup window
    this.isPopup = new URLSearchParams(window.location.search).get('popup') === 'true'
    console.log('🪟 Running in popup mode:', this.isPopup)
    
    // Initialize Nostr detection
    this.initializeNostrDetection()
  }

  initializeNostrDetection() {
    // Global variables to track Nostr readiness
    window.nostrReady = false
    window.nostrExtensionFound = false
    
    let checkCount = 0
    const maxChecks = 10 // Try for 10 seconds
    const checkInterval = 1000 // Check every second
    
    const checkForNostr = () => {
      checkCount++
      console.log(`Nostr check attempt ${checkCount}/${maxChecks} in bookmarklet popup`)
      
      // Debug: Log what's available in window
      console.log('window.nostr exists:', !!window.nostr)
      
      if (window.nostr) {
        console.log('window.nostr type:', typeof window.nostr)
        console.log('window.nostr object keys:', Object.keys(window.nostr))
        console.log('getPublicKey available:', typeof window.nostr.getPublicKey)
        console.log('signEvent available:', typeof window.nostr.signEvent)
        
        const hasPubkey = typeof window.nostr.getPublicKey === 'function'
        const hasSignEvent = typeof window.nostr.signEvent === 'function'
        
        if (hasPubkey && hasSignEvent) {
          // Success! Nostr is ready
          window.nostrReady = true
          window.nostrExtensionFound = true
          
          this.statusTarget.textContent = "Nostr extension detected ✓"
          this.statusTarget.className = "nostr-status nostr-status-connected"
          console.log('✓ Nostr extension fully detected and ready in bookmarklet popup')
          
          // Try to get pubkey to verify it's really working
          window.nostr.getPublicKey()
            .then(pubkey => {
              this.statusTarget.textContent = `Nostr extension ready: ${pubkey.substring(0, 8)}...`
              console.log('✓ Nostr pubkey retrieved successfully in popup:', pubkey)
            })
            .catch(err => {
              console.log('Note: Error getting pubkey (user may need to approve):', err.message)
              // Don't change status - extension is still ready, user just needs to approve
            })
          
          return // Stop checking
        } else {
          let missingMethods = []
          if (!hasPubkey) missingMethods.push("getPublicKey")
          if (!hasSignEvent) missingMethods.push("signEvent")
          
          this.statusTarget.textContent = `Nostr extension missing: ${missingMethods.join(", ")}`
          this.statusTarget.className = "nostr-status nostr-status-error"
          console.log('✗ Nostr extension found but missing methods:', missingMethods)
          return // Stop checking
        }
      } else if (checkCount >= maxChecks) {
        // We've tried enough times, give up
        window.nostrReady = false
        window.nostrExtensionFound = false
        
        this.statusTarget.textContent = "No Nostr extension detected. Bookmark will be saved without signing."
        this.statusTarget.className = "nostr-status nostr-status-disconnected"
        console.log('✗ No Nostr extension found after', maxChecks, 'seconds in popup')
        return
      } else {
        // Still checking
        this.statusTarget.textContent = `Checking for Nostr extension... (${checkCount}/${maxChecks})`
        console.log(`⏳ Nostr not found yet in popup, continuing to check... (${checkCount}/${maxChecks})`)
        setTimeout(checkForNostr, checkInterval)
      }
    }
    
    // Start checking immediately
    checkForNostr()
  }

  async handleSubmit(event) {
    console.log('🎯 EMBEDDED JS: Form submit intercepted')
    
    // Prevent default form submission
    event.preventDefault()
    
    // Prevent multiple submissions
    if (this.formSubmitting) {
      console.log('Form already submitting, ignoring duplicate')
      return
    }
    
    this.formSubmitting = true
    
    // Disable submit button
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = true
      this.submitButtonTarget.textContent = 'Saving...'
    }
    
    try {
      // Get form data
      const title = this.titleTarget.value
      const url = this.urlTarget.value
      const description = this.hasDescriptionTarget ? this.descriptionTarget.value : ''
      
      console.log('📝 Form data:', { title, url, description })
      
      // Update status
      if (this.hasStatusTarget) {
        this.statusTarget.textContent = "Processing bookmark..."
        this.statusTarget.className = "nostr-status"
      }
      
      // Check Nostr readiness
      console.log('🔍 Checking Nostr readiness...')
      console.log('  window.nostrReady:', window.nostrReady)
      console.log('  window.nostr exists:', !!window.nostr)
      
      // Try Nostr signing if available
      let nostrSuccess = false
      
      if (window.nostrReady === true && window.nostr && 
          typeof window.nostr.getPublicKey === 'function' && 
          typeof window.nostr.signEvent === 'function') {
        try {
          console.log('🔐 Attempting Nostr signing...')
          if (this.hasStatusTarget) {
            this.statusTarget.textContent = "Attempting Nostr signing..."
          }
          
          nostrSuccess = await this.attemptNostrSigning(title, url, description)
          console.log('🎯 CRITICAL: Nostr signing result:', nostrSuccess)
        } catch (error) {
          console.error('❌ Error in Nostr signing:', error)
          if (this.hasStatusTarget) {
            this.statusTarget.textContent = `Nostr error: ${error.message}. Submitting without signing.`
            this.statusTarget.className = "nostr-status nostr-status-error"
          }
        }
      } else {
        console.log('❌ Nostr not ready, submitting directly')
        if (this.hasStatusTarget) {
          this.statusTarget.textContent = "No Nostr extension ready. Submitting directly."
          this.statusTarget.className = "nostr-status nostr-status-disconnected"
        }
      }
      
      // If Nostr signing didn't work, submit directly
      if (!nostrSuccess) {
        console.log('📤 Falling back to direct submission')
        await this.submitFormDirectly(title, url, description)
      }
    } catch (error) {
      console.error('❌ Unhandled error:', error)
      
      // Re-enable form
      this.formSubmitting = false
      if (this.hasSubmitButtonTarget) {
        this.submitButtonTarget.disabled = false
        this.submitButtonTarget.textContent = 'Save Bookmark'
      }
      
      alert('An error occurred: ' + error.message)
    }
  }

  async attemptNostrSigning(title, url, description) {
    console.log('🔐 Starting Nostr signing attempt')
    
    try {
      // Step 1: Get public key
      console.log('🔑 Step 1: Getting public key...')
      if (this.hasStatusTarget) {
        this.statusTarget.textContent = "Requesting Nostr public key..."
      }
      
      const pubkey = await window.nostr.getPublicKey()
      console.log('✅ Got pubkey:', pubkey)
      
      // Step 2: Prepare event
      console.log('📝 Step 2: Preparing event...')
      if (this.hasStatusTarget) {
        this.statusTarget.textContent = "Preparing Nostr event..."
      }
      
      const event = this.prepareNostrEvent(title, url, description, pubkey)
      console.log('✅ Prepared event:', event)
      
      // Step 3: Sign event
      console.log('✍️ Step 3: Requesting signature...')
      if (this.hasStatusTarget) {
        this.statusTarget.textContent = "Requesting Nostr signature..."
      }
      
      const signedEvent = await window.nostr.signEvent(event)
      console.log('✅ Got signed event:', signedEvent)
      
      // Step 4: Validate
      if (!signedEvent || !signedEvent.sig || !signedEvent.id) {
        console.error('❌ Invalid signed event')
        return false
      }
      
      // Step 5: Submit to server
      console.log('🚀 Step 5: Submitting to server...')
      if (this.hasStatusTarget) {
        this.statusTarget.textContent = "Successfully signed! Submitting..."
        this.statusTarget.className = "nostr-status nostr-status-connected"
      }
      
      const result = await this.submitToServer(signedEvent, title, url, description, true)
      return result
    } catch (error) {
      console.error('❌ Error in Nostr signing:', error)
      throw error
    }
  }

  prepareNostrEvent(title, url, description, pubkey) {
    // Extract d-tag from URL
    const urlWithoutScheme = this.extractUrlDTag(url)
    console.log('🏷️ Extracted d-tag:', urlWithoutScheme)
    
    const now = Math.floor(Date.now() / 1000)
    
    const tags = [
      ["d", urlWithoutScheme],
      ["title", title],
      ["published_at", now.toString()]
    ]
    
    // Add hashtags
    const hashtags = this.extractHashtags(description)
    hashtags.forEach(tag => {
      tags.push(["t", tag])
    })
    
    return {
      kind: 39701,
      pubkey: pubkey,
      created_at: now,
      tags: tags,
      content: description
    }
  }

  extractUrlDTag(url) {
    try {
      let fullUrl = url
      if (!url.match(/^https?:\/\//i)) {
        fullUrl = "https://" + url
      }
      
      const urlObj = new URL(fullUrl)
      return urlObj.hostname + urlObj.pathname
    } catch (e) {
      console.error("Error parsing URL:", e)
      return url.replace(/^https?:\/\//i, '')
    }
  }

  extractHashtags(content) {
    if (!content) return []
    
    const hashtags = []
    const matches = content.match(/(?:\s|^)#([\w\d]+)/g) || []
    
    matches.forEach(match => {
      const tag = match.trim().substring(1)
      if (tag && tag.length > 0) {
        hashtags.push(tag)
      }
    })
    
    return hashtags
  }

  async submitToServer(signedEvent, title, url, description, nostrSigned = false) {
    console.log('📤 Submitting to server with signed event')
    console.log('📤 Signed event:', signedEvent)
    
    const csrfToken = document.querySelector('meta[name="csrf-token"]').content
    
    const payload = {
      signed_event: signedEvent,
      bookmark: {
        title: title,
        url: url,
        description: description
      },
      popup: this.isPopup ? true : undefined
    }
    
    console.log('📤 Full payload:', JSON.stringify(payload, null, 2))
    
    try {
      const actionUrl = this.formTarget.getAttribute('action')
      const response = await fetch(actionUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-CSRF-Token': csrfToken
        },
        body: JSON.stringify(payload)
      })
      
      console.log('📥 Server response status:', response.status)
      
      if (!response.ok) {
        const errorData = await response.json()
        console.error('❌ Server error:', errorData)
        throw new Error(errorData.errors ? errorData.errors.join(', ') : 'Server error')
      }
      
      const data = await response.json()
      console.log('✅ Server success:', data)
      
      // Show success message and auto-close
      this.showSuccessAndClose('Your bookmark has been successfully saved and signed with Nostr.', true)
      
      return true
    } catch (error) {
      console.error('❌ Error submitting to server:', error)
      alert('Failed to save bookmark: ' + error.message)
      return false
    }
  }

  async submitFormDirectly(title, url, description) {
    console.log('📤 Submitting form directly without Nostr')
    
    const formData = new FormData(this.formTarget)
    formData.append('direct_submission', 'true')
    
    try {
      const actionUrl = this.formTarget.getAttribute('action')
      const response = await fetch(actionUrl, {
        method: 'POST',
        body: formData,
        headers: {
          'Accept': 'text/html,application/xhtml+xml'
        },
        redirect: 'follow'
      })
      
      console.log('📤 Direct submission response:', response)
      
      if (response.ok) {
        // Show success message and auto-close
        this.showSuccessAndClose('Your bookmark has been successfully saved.', false)
      } else {
        throw new Error('Server returned an error')
      }
    } catch (error) {
      console.error('❌ Error in direct submission:', error)
      alert('Failed to submit form: ' + error.message)
      
      // Re-enable form
      this.formSubmitting = false
      if (this.hasSubmitButtonTarget) {
        this.submitButtonTarget.disabled = false
        this.submitButtonTarget.textContent = 'Save Bookmark'
      }
    }
  }

  showSuccessAndClose(message, nostrSigned) {
    console.log('🎉 Showing success message and preparing to close')
    
    const container = document.getElementById('form-container')
    
    // Show success message with Nostr status
    let nostrStatusHtml = ''
    if (nostrSigned) {
      nostrStatusHtml = '<div class="success-nostr-status success">✓ Bookmark signed with Nostr and will be published to relays</div>'
    } else {
      nostrStatusHtml = '<div class="success-nostr-status warning">ℹ️ Bookmark saved without Nostr signing</div>'
    }
    
    container.innerHTML = `
      <div class="success-message">
        <h2>Bookmark Saved!</h2>
        <p>${message || 'Your bookmark has been successfully saved to Pinstr.'}</p>
        ${nostrStatusHtml}
        <div class="auto-close-notice">
          <p><small>This window will close automatically in <span id="countdown">3</span> seconds...</small></p>
          <div class="buttons">
            <button type="button" class="btn btn-primary" onclick="window.close()">Close Now</button>
          </div>
        </div>
      </div>
    `
    
    // Countdown and auto-close
    let countdown = 3
    const countdownElement = document.getElementById('countdown')
    
    const countdownInterval = setInterval(() => {
      countdown--
      if (countdownElement) {
        countdownElement.textContent = countdown
      }
      
      if (countdown <= 0) {
        clearInterval(countdownInterval)
        console.log('⏰ Auto-closing popup window')
        
        // Only close if we're actually in a popup
        if (this.isPopup) {
          window.close()
        } else {
          // If not in popup, redirect to bookmarks page
          window.location.href = '/bookmarks'
        }
      }
    }, 1000)
  }

  cancelBookmark() {
    window.close()
  }
}