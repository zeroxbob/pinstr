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
    
    const content = formData.get("bookmark[title]");

    if (!content) {
      throw new Error("Bookmark title is required.");
    }

    return {
      content: content,
      created_at: Math.floor(Date.now() / 1000),
      pubkey: pubkey,
      kind: 30001,
      tags: [] 
    };
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
      if (response.redirected) {
        window.location.href = response.url;
        return;
      }
      if (!response.ok) {
        throw new Error('Network response was not ok.');
      }
      return response.json();
    }).then((data) => {
      console.log('Event successfully published:', data);
    }).catch((error) => {
      this.displayError("Failed to communicate with server: " + error.message);
    });
  }

  displayError(message) {
    alert(message);
  }
}
