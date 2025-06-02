import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "title", "url", "description"]
  
  connect() {
    console.log("Bookmarklet sign controller connected")
    // Use a one-time event listener to handle form submission
    this.formHandler = this.handleSubmit.bind(this)
    this.element.addEventListener('submit', this.formHandler, { once: true })
    
    // Set up a flag to track submission state
    this.element.dataset.submitting = "false"
  }
  
  disconnect() {
    // Clean up the event listener if the controller is disconnected
    this.element.removeEventListener('submit', this.formHandler)
  }

  async handleSubmit(event) {
    // Prevent the default form submission
    event.preventDefault()
    
    // Check if we're already submitting to avoid duplicate submissions
    if (this.element.dataset.submitting === "true") {
      console.log("Form already being submitted, ignoring duplicate")
      return
    }
    
    // Mark as submitting
    this.element.dataset.submitting = "true"
    
    // Disable submit button
    const submitButton = document.getElementById('submit-button')
    if (submitButton) {
      submitButton.disabled = true
      submitButton.textContent = 'Saving...'
    }
    
    try {
      // Get form data
      const title = this.titleTarget.value
      const url = this.urlTarget.value
      const description = this.descriptionTarget.value || ""
      
      // Update the status
      const statusElement = document.getElementById('nostr-status')
      if (statusElement) {
        statusElement.textContent = "Processing bookmark..."
        statusElement.className = "nostr-status"
      }
      
      // Wait a bit for Nostr detection to complete if it's still running
      console.log("Checking Nostr readiness at submission time...")
      console.log("window.nostrReady:", window.nostrReady)
      console.log("window.nostrExtensionFound:", window.nostrExtensionFound)
      console.log("window.nostr exists:", !!window.nostr)
      
      // If Nostr detection hasn't finished yet, wait a bit more
      if (window.nostrReady === undefined || window.nostrExtensionFound === undefined) {
        console.log("Nostr detection still in progress, waiting...")
        if (statusElement) {
          statusElement.textContent = "Waiting for Nostr detection to complete..."
        }
        
        // Wait up to 3 more seconds for detection to complete
        for (let i = 0; i < 3; i++) {
          await new Promise(resolve => setTimeout(resolve, 1000))
          console.log(`Additional wait ${i + 1}/3 - Nostr ready: ${window.nostrReady}`)
          
          if (window.nostrReady !== undefined) {
            console.log("Nostr detection completed during wait")
            break
          }
        }
      }
      
      // Try Nostr signing if available and ready
      let nostrSuccess = false
      
      if (window.nostrReady === true && window.nostr && 
          typeof window.nostr.getPublicKey === 'function' && 
          typeof window.nostr.signEvent === 'function') {
        try {
          console.log("✓ Attempting Nostr signing - extension is ready")
          if (statusElement) {
            statusElement.textContent = "Attempting Nostr signing..."
            statusElement.className = "nostr-status"
          }
          
          nostrSuccess = await this.attemptNostrSigningWithTimeout(title, url, description, statusElement)
          console.log("🎯 CRITICAL: Nostr signing result:", nostrSuccess)
          
          // Additional debug info
          if (nostrSuccess) {
            console.log("✅ SUCCESS: Nostr signing was successful, bookmark should be signed")
          } else {
            console.log("❌ FAILURE: Nostr signing failed, will submit without signing")
          }
        } catch (error) {
          console.error("✗ Error in Nostr signing:", error)
          if (statusElement) {
            statusElement.textContent = `Nostr error: ${error.message}. Submitting without signing.`
            statusElement.className = "nostr-status nostr-status-error"
          }
        }
      } else {
        console.log("✗ Nostr not ready or available, submitting directly")
        console.log("  - window.nostrReady:", window.nostrReady)
        console.log("  - window.nostr exists:", !!window.nostr)
        
        if (statusElement) {
          statusElement.textContent = "No Nostr extension detected. Submitting directly."
          statusElement.className = "nostr-status nostr-status-disconnected"
        }
      }
      
      // If Nostr signing didn't work, submit directly
      if (!nostrSuccess) {
        console.log("➜ Falling back to direct submission")
        this.submitFormDirectly()
      }
    } catch (error) {
      console.error("✗ Unhandled error in form submission:", error)
      
      // Re-enable form in case of error
      this.element.dataset.submitting = "false"
      
      const submitButton = document.getElementById('submit-button')
      if (submitButton) {
        submitButton.disabled = false
        submitButton.textContent = 'Save Bookmark'
      }
      
      this.displayError("An unexpected error occurred: " + error.message)
    }
  }
  
  // Try Nostr signing with a timeout to avoid hanging
  async attemptNostrSigningWithTimeout(title, url, description, statusElement) {
    console.log("🔐 Starting Nostr signing attempt with timeout")
    
    return new Promise(async (resolve, reject) => {
      // Set a timeout to avoid waiting forever for Nostr
      const timeoutId = setTimeout(() => {
        console.warn("⏰ Nostr signing timed out after 10 seconds")
        if (statusElement) {
          statusElement.textContent = "Nostr signing timed out. Submitting without signing."
          statusElement.className = "nostr-status nostr-status-error"
        }
        resolve(false)
      }, 10000) // 10 second timeout
      
      try {
        console.log("🔑 Step 1: Getting Nostr public key...")
        
        // Get the pubkey first - this also checks permissions
        if (statusElement) {
          statusElement.textContent = "Requesting Nostr public key..."
        }
        
        const pubkey = await window.nostr.getPublicKey()
        console.log("✓ Got Nostr pubkey:", pubkey)
        
        console.log("📝 Step 2: Preparing Nostr event...")
        
        // Prepare the event
        if (statusElement) {
          statusElement.textContent = "Preparing Nostr event..."
        }
        
        const event = this.prepareNostrEvent(title, url, description, pubkey)
        console.log("✓ Prepared Nostr event:", event)
        
        console.log("✍️ Step 3: Requesting Nostr signature...")
        
        // Request signing - this is where problems might occur
        if (statusElement) {
          statusElement.textContent = "Requesting Nostr signature..."
        }
        
        console.log("🔏 Requesting Nostr signature - SINGLE ATTEMPT")
        
        // THIS IS THE CRITICAL PART - the signEvent call
        const signedEvent = await window.nostr.signEvent(event)
        console.log("✓ Got signed event:", signedEvent)
        
        // Cancel the timeout since we got a response
        clearTimeout(timeoutId)
        
        console.log("🔍 Step 4: Validating signed event...")
        
        // Validate the signed event
        if (!signedEvent || !signedEvent.sig || !signedEvent.id) {
          console.error("✗ Invalid signed event returned")
          resolve(false)
          return
        }
        
        console.log("✅ Signed event validation passed")
        console.log("🚀 Step 5: Submitting to server...")
        
        // Success! Submit with the signed event
        if (statusElement) {
          statusElement.textContent = "Successfully signed! Submitting..."
          statusElement.className = "nostr-status nostr-status-connected"
        }
        
        // Submit to the server - THIS IS WHERE THE PROBLEM MIGHT BE
        try {
          const result = await this.submitToServer(signedEvent, title, url, description)
          console.log("🎯 CRITICAL: Server submission result:", result)
          
          // Resolve with the actual result from submitToServer
          resolve(result)
        } catch (serverError) {
          console.error("❌ Error submitting to server:", serverError)
          resolve(false)
        }
      } catch (error) {
        // Cancel the timeout on error
        clearTimeout(timeoutId)
        console.error("✗ Error in Nostr signing process:", error)
        reject(error)
      }
    })
  }
  
  prepareNostrEvent(title, url, description, pubkey) {
    // Extract d-tag from URL according to NIP-B0
    const urlWithoutScheme = this.extractUrlDTag(url)
    console.log("🏷️ Extracted d-tag from URL:", urlWithoutScheme)
    
    // Create timestamp
    const now = Math.floor(Date.now() / 1000)
    
    // Build tags array according to NIP-B0
    const tags = [
      ["d", urlWithoutScheme], // Required d tag for the bookmark identifier
      ["title", title],        // Title tag for the bookmark
      ["published_at", now.toString()] // Optional published_at tag
    ]
    
    // Extract hashtags from description
    const hashtags = this.extractHashtags(description)
    console.log("🏷️ Extracted hashtags:", hashtags)
    
    // Add hashtags as t tags
    hashtags.forEach(tag => {
      tags.push(["t", tag])
    })
    
    // Prepare event object according to NIP-01 and NIP-B0
    return {
      kind: 39701,         // NIP-B0 bookmark kind
      pubkey: pubkey,      // Public key from extension
      created_at: now,     // Current timestamp
      tags: tags,          // Tags array
      content: description // Description as content
    }
  }
  
  // Extract d-tag from URL according to NIP-B0
  extractUrlDTag(url) {
    try {
      // Make sure URL has http/https prefix
      let fullUrl = url
      if (!url.match(/^https?:\/\//i)) {
        fullUrl = "https://" + url
      }
      
      // Parse the URL to get its parts
      const urlObj = new URL(fullUrl)
      
      // Get hostname + pathname without query or hash
      return urlObj.hostname + urlObj.pathname
    } catch (e) {
      console.error("Error parsing URL:", e)
      return url.replace(/^https?:\/\//i, '')
    }
  }
  
  // Extract hashtags from description text
  extractHashtags(content) {
    if (!content) return []
    
    const hashtags = []
    const matches = content.match(/(?:\s|^)#([\w\d]+)/g) || []
    
    matches.forEach(match => {
      const tag = match.trim().substring(1) // Remove # symbol
      if (tag && tag.length > 0) {
        hashtags.push(tag)
      }
    })
    
    return hashtags
  }
  
  // Submit the form directly (without Nostr)
  submitFormDirectly() {
    console.log("📤 Submitting form directly without Nostr")
    
    const formData = new FormData(this.element)
    formData.append('direct_submission', 'true')
    
    // Use fetch to submit the form
    fetch(this.element.action, {
      method: 'POST',
      body: formData,
      headers: {
        'Accept': 'text/html,application/xhtml+xml'
      },
      redirect: 'follow'
    })
    .then(response => {
      console.log("📤 Direct submission response:", response)
      // Handle the response - for HTML submissions we'll just follow redirects
      if (response.redirected) {
        console.log("🔀 Redirecting to:", response.url)
        window.location.href = response.url
      } else {
        console.log("🔄 No redirect received, reloading page")
        window.location.reload()
      }
    })
    .catch(error => {
      console.error("✗ Error submitting form:", error)
      this.displayError("Failed to submit form: " + error.message)
      
      // Re-enable form in case of error
      this.element.dataset.submitting = "false"
      
      const submitButton = document.getElementById('submit-button')
      if (submitButton) {
        submitButton.disabled = false
        submitButton.textContent = 'Save Bookmark'
      }
    })
  }
  
  // Submit to server with signed event
  async submitToServer(signedEvent, title, url, description) {
    console.log("📤 Submitting to server with signed event")
    console.log("🔍 Signed event details:")
    console.log("  - ID:", signedEvent.id)
    console.log("  - Kind:", signedEvent.kind)
    console.log("  - Pubkey:", signedEvent.pubkey)
    console.log("  - Signature:", signedEvent.sig)
    console.log("  - Tags:", signedEvent.tags)
    console.log("  - Content:", signedEvent.content)
    
    const csrfToken = document.querySelector('meta[name="csrf-token"]').content
    const isPopup = new URLSearchParams(window.location.search).get('popup') === 'true'
    
    // Make a clean copy of the signed event
    const eventCopy = JSON.parse(JSON.stringify(signedEvent))
    
    // Build the payload
    const payload = {
      signed_event: eventCopy,
      bookmark: {
        title: title,
        url: url,
        description: description
      },
      popup: isPopup ? true : undefined
    }
    
    console.log("📤 Full payload being sent to server:")
    console.log(JSON.stringify(payload, null, 2))
    console.log("📤 CSRF Token:", csrfToken)
    console.log("📤 Request URL:", this.element.action)
    
    try {
      // Send it to the server
      const response = await fetch(this.element.action, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-CSRF-Token': csrfToken
        },
        body: JSON.stringify(payload)
      })
      
      console.log("📥 Server response status:", response.status)
      console.log("📥 Server response headers:", response.headers)
      
      if (!response.ok) {
        const errorData = await response.json()
        console.error("❌ Server error response:", errorData)
        throw new Error(errorData.errors ? errorData.errors.join(', ') : 'Server returned an error')
      }
      
      const data = await response.json()
      console.log("✅ Server success response:", data)
      
      if (data.redirect_url) {
        // Redirect to the success page
        console.log("🔀 Redirecting to:", data.redirect_url)
        window.location.href = data.redirect_url
      } else {
        // No redirect URL, show success in place
        console.log("✅ No redirect, showing success message in place")
        document.getElementById('form-container').innerHTML = '<div class="success-message"><h2>Bookmark Saved!</h2><p>Your bookmark has been successfully saved and signed with Nostr.</p><div class="buttons"><button type="button" class="btn btn-primary" onclick="window.close()">Close</button></div></div>'
      }
      
      return true
    } catch (error) {
      console.error("❌ Error submitting to server:", error)
      this.displayError("Failed to save bookmark: " + error.message)
      return false
    }
  }
  
  // Show an error message to the user
  displayError(message) {
    console.error(message)
    
    // Try to find or create an error element
    let errorElement = document.getElementById('form-error')
    if (!errorElement) {
      errorElement = document.createElement('div')
      errorElement.id = 'form-error'
      errorElement.className = 'alert'
      this.element.prepend(errorElement)
    }
    
    errorElement.textContent = message
    errorElement.style.display = 'block'
  }
}
