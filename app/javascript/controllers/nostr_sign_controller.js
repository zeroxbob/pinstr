import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.addEventListener('submit', this.handleSubmit.bind(this))
  }

  async handleSubmit(event) {
    event.preventDefault()

    try {
      const formData = new FormData(this.element)
      const nostrEvent = this.prepareNostrEvent(formData)

      const signedEvent = await this.signEventWithExtension(nostrEvent)

      if (signedEvent) {
        this.submitToRailsBackend(signedEvent)
      } else {
        this.displayError("Signing failed: No signature returned.")
      }
    } catch (error) {
      this.displayError("An error occurred: " + error.message)
    }
  }

  prepareNostrEvent(formData) {
    // Extract the event data from the form and prepare it
    return {
      // Placeholder for the actual event structure
      content: formData.get("content"),
      created_at: Math.floor(Date.now() / 1000),
      pubkey: "your-public-key-here", // This may be dynamically set
      // More fields as needed by Nostr
    }
  }

  async signEventWithExtension(event) {
    // Interact with the browser extension to sign the event
    return new Promise((resolve, reject) => {
      // Assuming the extension exposes a `nostr_signEvent` method
      if (window.nostr && window.nostr.signEvent) {
        window.nostr.signEvent(event).then(resolve).catch(reject)
      } else {
        reject(new Error("Nostr extension not available."))
      }
    })
  }

  submitToRailsBackend(signedEvent) {
    // Logic to send the signed event to the backend
    fetch(this.element.action, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: JSON.stringify({ event: signedEvent }),
    }).then((response) => {
      if (!response.ok) {
        throw new Error('Network response was not ok.');
      }
      return response.json()
    }).then((data) => {
      // Handle successful response
      console.log('Event successfully published:', data)
    }).catch((error) => {
      this.displayError("Failed to communicate with server: " + error.message)
    })
  }

  displayError(message) {
    // Handle the error messaging, e.g., display to user
    alert(message)
  }
}
