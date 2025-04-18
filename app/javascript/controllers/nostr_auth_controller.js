import { Controller } from "@hotwired/stimulus"

// Stimulus controller for Nostr authentication
// Manages detection of Nostr extension, requesting public key, and login/logout.
export default class extends Controller {
  static targets = ["loginButton", "status", "logoutButton"]

  connect() {
    this.checkNostrExtension()
  }

  checkNostrExtension() {
    // Check if a window.nostr object is present
    if (window.nostr) {
      this.statusTarget.textContent = "Nostr extension detected"
      this.loginButtonTarget.disabled = false
    } else {
      this.statusTarget.textContent = "No Nostr extension detected"
      this.loginButtonTarget.disabled = true
    }
  }

  async requestPublicKey() {
    if (!window.nostr) {
      alert("Nostr extension not found.")
      return
    }
    try {
      const pubkey = await window.nostr.getPublicKey()
      return pubkey
    } catch (e) {
      console.error("Failed to get Nostr pubkey", e)
      alert("Failed to retrieve public key from Nostr.")
    }
  }

  async login() {
    const pubkey = await this.requestPublicKey()
    if (!pubkey) return

    // Send POST to /auth with the pubkey
    const response = await fetch("/auth", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": this.getMetaValue("csrf-token")
      },
      body: JSON.stringify({ public_key: pubkey })
    })

    if (response.ok) {
      window.location.reload()
    } else {
      alert("Login failed")
    }
  }

  async logout() {
    const response = await fetch("/auth", {
      method: "DELETE",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": this.getMetaValue("csrf-token")
      }
    })

    if (response.ok) {
      window.location.reload()
    } else {
      alert("Logout failed")
    }
  }

  getMetaValue(name) {
    const element = document.head.querySelector(`meta[name=\"${name}\"]`)
    return element && element.getAttribute("content")
  }
}
