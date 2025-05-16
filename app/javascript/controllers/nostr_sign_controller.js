import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.addEventListener('submit', this.handleSubmit.bind(this))
  }

  async handleSubmit(event) {
    event.preventDefault()

    try {
      const formData = new FormData(this.element);
      const nostrEvent = await this.prepareNostrEvent(formData);

      const signedEvent = await this.signEventWithExtension(nostrEvent);

      if (signedEvent) {
        this.submitToRailsBackend(signedEvent, formData);
      } else {
        this.displayError("Signing failed: No signature returned.");
      }
    } catch (error) {
      this.displayError("An error occurred: " + error.message);
    }
  }

  async prepareNostrEvent(formData) {
    let pubkey = null;

    if (window.nostr && window.nostr.getPublicKey) {
      try {
        pubkey = await window.nostr.getPublicKey();
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
    const now = Math.floor(Date.now() / 1000);
    
    // Build tags array according to NIP-B0
    const tags = [
      ["d", urlWithoutScheme], // Required d tag
      ["published_at", now.toString()], // Optional published_at tag
      ["title", title] // Optional title tag
    ];
    
    // Add hashtags if description contains any
    const hashtags = this.extractHashtags(description);
    hashtags.forEach(tag => {
      tags.push(["t", tag]);
    });

    return {
      content: description,
      created_at: now,
      pubkey: pubkey,
      kind: 39701, // NIP-B0 kind for web bookmarks
      tags: tags
    };
  }

  // Extract the d-tag value from a URL according to NIP-B0
  extractUrlDTag(url) {
    try {
      // Parse the URL
      const parsedUrl = new URL(url);
      
      // Remove scheme (http:// or https://)
      let dTag = url.replace(/^https?:\/\//, '');
      
      // Remove querystring and hash unless explicitly needed
      dTag = dTag.split('?')[0].split('#')[0];
      
      return dTag;
    } catch(e) {
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
        window.nostr.signEvent(event).then(resolve).catch(reject);
      } else {
        reject(new Error("Nostr extension not available."));
      }
    });
  }

  submitToRailsBackend(signedEvent, formData) {
    const csrfToken = document.querySelector('meta[name="csrf-token"]').content;

    fetch(this.element.action, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-CSRF-Token': csrfToken
      },
      body: JSON.stringify({
        signed_event: signedEvent,
        bookmark: {
          title: formData.get('bookmark[title]'),
          url: formData.get('bookmark[url]'),
          description: formData.get('bookmark[description]')
        }
      }),
    }).then((response) => {
      if (!response.ok) {
        throw new Error('Network response was not ok.');
      }
      return response.json();
    }).then((data) => {
      if (data.redirect_url) {
        window.location.href = data.redirect_url;
      } else {
        console.log('Event successfully published:', data);
      }
    }).catch((error) => {
      this.displayError("Failed to communicate with server: " + error.message);
    });
  }

  displayError(message) {
    alert(message);
  }
}
