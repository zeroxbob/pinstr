import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.addEventListener('submit', this.handleSubmit.bind(this))
    console.log("Bookmarklet sign controller connected")
  }

  async handleSubmit(event) {
    event.preventDefault()

    try {
      // Validate form first
      const formData = new FormData(this.element);
      const title = formData.get("bookmark[title]");
      const url = formData.get("bookmark[url]");
      
      if (!title || !url) {
        this.displayError("Title and URL are required fields");
        return;
      }
      
      if (!url.match(/^https?:\/\//)) {
        // Add https:// if missing
        const urlField = this.element.querySelector('input[name="bookmark[url]"]');
        urlField.value = "https://" + url;
        formData.set("bookmark[url]", "https://" + url);
      }

      // Check if Nostr extension is available
      if (!window.nostr) {
        console.log("Nostr extension not available, submitting form without signing");
        // Just submit the form without signing
        this.element.removeEventListener('submit', this.handleSubmit.bind(this));
        this.element.submit();
        return;
      }

      // Prepare and sign the event
      const nostrEvent = await this.prepareNostrEvent(formData);
      console.log("Prepared NIP-B0 event:", JSON.stringify(nostrEvent, null, 2));

      const signedEvent = await this.signEventWithExtension(nostrEvent);
      console.log("Signed NIP-B0 event:", JSON.stringify(signedEvent, null, 2));
      
      // Additional debug checks for the signed event
      this.validateSignedEvent(signedEvent);

      if (signedEvent) {
        this.submitToRailsBackend(signedEvent, formData);
      } else {
        this.displayError("Signing failed: No signature returned.");
      }
    } catch (error) {
      console.error("Error in form submission:", error);
      this.displayError("An error occurred: " + error.message);
    }
  }
  
  // Add this method to validate the signed event
  validateSignedEvent(event) {
    console.log("Validating signed event...");
    
    if (!event) {
      console.error("Event is null or undefined");
      return false;
    }
    
    // Make sure all properties are present with the correct type
    if (typeof event.kind !== 'number') {
      console.error(`Wrong event kind type: ${typeof event.kind} - should be number`);
      // Force it to be a number
      event.kind = Number(event.kind) || 39701;
      console.log("Fixed event kind to:", event.kind);
    } else {
      console.log("✓ Kind is correct type: number");
    }
    
    if (event.kind !== 39701) {
      console.error(`Wrong event kind value: ${event.kind} - should be 39701`);
      // Force the correct value
      event.kind = 39701;
      console.log("Fixed event kind to 39701");
    } else {
      console.log("✓ Kind is correct value: 39701");
    }
    
    // Check other required fields
    console.log("Event ID:", event.id);
    console.log("Event pubkey:", event.pubkey);
    console.log("Event signature:", event.sig);
    console.log("Event content:", event.content);
    console.log("Event created_at:", event.created_at);
    
    // Tags validation
    if (!Array.isArray(event.tags)) {
      console.error("Tags is not an array:", event.tags);
    } else {
      console.log("Tags:", event.tags);
      
      // Check for d tag (required by NIP-B0)
      const dTag = event.tags.find(tag => tag[0] === 'd');
      if (!dTag) {
        console.error("Missing required 'd' tag");
      } else {
        console.log("✓ Found 'd' tag:", dTag[1]);
      }
      
      // Check for title tag
      const titleTag = event.tags.find(tag => tag[0] === 'title');
      if (!titleTag) {
        console.error("Missing 'title' tag");
      } else {
        console.log("✓ Found 'title' tag:", titleTag[1]);
      }
    }
    
    return true;
  }

  async prepareNostrEvent(formData) {
    let pubkey = null;

    if (window.nostr && window.nostr.getPublicKey) {
      try {
        pubkey = await window.nostr.getPublicKey();
        console.log("Retrieved public key:", pubkey);
      } catch (error) {
        console.error("Failed to get public key from extension:", error);
        throw new Error("Public key retrieval failed.");
      }
    }

    if (!pubkey) {
      throw new Error("Nostr public key is unavailable.");
    }
    
    const title = formData.get("bookmark[title]");
    const url = formData.get("bookmark[url]");
    const description = formData.get("bookmark[description]") || '';

    if (!title) {
      throw new Error("Bookmark title is required.");
    }

    if (!url) {
      throw new Error("Bookmark URL is required.");
    }

    // Create NIP-B0 compliant event (kind 39701)
    const urlWithoutScheme = this.extractUrlDTag(url);
    console.log("Extracted d-tag from URL:", urlWithoutScheme);
    
    const now = Math.floor(Date.now() / 1000);
    
    // Build tags array according to NIP-B0
    const tags = [
      ["d", urlWithoutScheme], // Required d tag
      ["published_at", now.toString()], // Optional published_at tag
      ["title", title] // Optional title tag
    ];
    
    // Add hashtags if description contains any
    const hashtags = this.extractHashtags(description);
    console.log("Extracted hashtags:", hashtags);
    
    hashtags.forEach(tag => {
      tags.push(["t", tag]);
    });

    return {
      content: description,
      created_at: now,
      pubkey: pubkey,
      kind: 39701, // NIP-B0 kind for web bookmarks - make sure it's a number!
      tags: tags
    };
  }

  // Extract the d-tag value from a URL according to NIP-B0
  extractUrlDTag(url) {
    try {
      // Parse the URL
      const parsedUrl = new URL(url);
      console.log("Parsed URL:", parsedUrl);
      
      // Remove scheme (http:// or https://)
      let dTag = url.replace(/^https?:\/\//, '');
      
      // Remove querystring and hash unless explicitly needed
      dTag = dTag.split('?')[0].split('#')[0];
      
      return dTag;
    } catch(e) {
      console.error("Error parsing URL:", e);
      // If parsing fails, just return the URL as is with scheme removed
      return url.replace(/^https?:\/\//, '');
    }
  }
  
  // Simple hashtag extractor from content
  extractHashtags(content) {
    if (!content) return [];
    
    const hashtags = [];
    const matches = content.match(/(?:\s|^)#([\w\d]+)/g) || [];
    
    matches.forEach(match => {
      const tag = match.trim().substring(1); // Remove # symbol
      if (tag.length > 0) {
        hashtags.push(tag);
      }
    });
    
    return hashtags;
  }

  async signEventWithExtension(event) {
    return new Promise((resolve, reject) => {
      if (window.nostr && window.nostr.signEvent) {
        console.log("Calling window.nostr.signEvent with event:", event);
        window.nostr.signEvent(event)
          .then(signedEvent => {
            console.log("NIP-B0 event signed successfully");
            // Ensure the kind is a number (some extensions might convert it to string)
            if (typeof signedEvent.kind !== 'number') {
              console.log("Converting kind to number after signing");
              signedEvent.kind = Number(signedEvent.kind) || 39701;
            }
            resolve(signedEvent);
          })
          .catch(error => {
            console.error("Signing error:", error);
            reject(error);
          });
      } else {
        reject(new Error("Nostr extension not available."));
      }
    });
  }

  submitToRailsBackend(signedEvent, formData) {
    const csrfToken = document.querySelector('meta[name="csrf-token"]').content;

    console.log("Submitting NIP-B0 event to server");
    
    // Ensure the signed event has the correct kind value as a number
    if (typeof signedEvent.kind !== 'number' || signedEvent.kind !== 39701) {
      console.warn("Event kind is not 39701 or not a number, fixing it...");
      signedEvent.kind = 39701;
    }
    
    // Create a plain object from signedEvent to ensure it's serialized properly
    const signedEventPlain = JSON.parse(JSON.stringify(signedEvent));
    
    // Get popup value if present
    const isPopup = new URLSearchParams(window.location.search).get('popup');
    
    const payload = {
      signed_event: signedEventPlain,
      bookmark: {
        title: formData.get('bookmark[title]'),
        url: formData.get('bookmark[url]'),
        description: formData.get('bookmark[description]')
      },
      popup: isPopup
    };
    
    console.log("Sending payload to server:", JSON.stringify(payload, null, 2));
    
    fetch(this.element.action, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-CSRF-Token': csrfToken
      },
      body: JSON.stringify(payload),
    }).then((response) => {
      console.log("Server response status:", response.status);
      if (!response.ok) {
        return response.json().then(data => {
          console.error("Server error data:", data);
          throw new Error(data.errors ? data.errors.join(', ') : 'Network response was not ok');
        });
      }
      return response.json();
    }).then((data) => {
      console.log("Server success response:", data);
      if (data.redirect_url) {
        window.location.href = data.redirect_url;
      } else {
        console.log('NIP-B0 event successfully published:', data);
        // If in popup mode, refresh the page to show success screen
        if (isPopup) {
          window.location.reload();
        } else {
          alert('Bookmark successfully created!');
        }
      }
    }).catch((error) => {
      console.error("Server error:", error);
      this.displayError("Failed to communicate with server: " + error.message);
    });
  }

  displayError(message) {
    console.error(message);
    alert(message);
  }
}
