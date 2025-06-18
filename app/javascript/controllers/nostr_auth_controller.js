import { Controller } from "@hotwired/stimulus"

// Stimulus controller for Nostr authentication
// Manages detection of Nostr extension, requesting public key, and login.
export default class extends Controller {
  static targets = ["loginButton", "status"]

  connect() {
    console.log("Nostr auth controller connected");
    
    // Only do status-related operations if we have a status target
    if (this.hasStatusTarget) {
      this.checkNostrExtension();
      
      // Check for extension every second in case it loads after the page
      this.extensionCheckInterval = setInterval(() => {
        this.checkNostrExtension();
      }, 1000);
    }
  }
  
  disconnect() {
    // Clear interval when controller disconnects
    if (this.extensionCheckInterval) {
      clearInterval(this.extensionCheckInterval);
    }
  }

  checkNostrExtension() {
    console.log("Checking for Nostr extension...");
    console.log("window.nostr exists:", !!window.nostr);
    
    if (window.nostr) {
      console.log("Nostr methods:", Object.keys(window.nostr));
      
      if (this.hasStatusTarget) {
        this.statusTarget.textContent = "Nostr extension detected ✓";
        this.statusTarget.classList.remove("text-danger");
        this.statusTarget.classList.add("text-success");
      }
      if (this.hasLoginButtonTarget) {
        this.loginButtonTarget.disabled = false;
      }
      
      // Clear interval once extension is detected
      if (this.extensionCheckInterval) {
        clearInterval(this.extensionCheckInterval);
      }
    } else {
      if (this.hasStatusTarget) {
        this.statusTarget.textContent = "No Nostr extension detected. Please install a Nostr extension.";
        this.statusTarget.classList.remove("text-success");
        this.statusTarget.classList.add("text-danger");
      }
      if (this.hasLoginButtonTarget) {
        this.loginButtonTarget.disabled = true;
      }
    }
  }

  async requestPublicKey() {
    console.log("Requesting public key...");
    
    if (!window.nostr) {
      console.error("No Nostr extension found");
      alert("Nostr extension not found.");
      return;
    }
    
    try {
      console.log("Calling window.nostr.getPublicKey()");
      const pubkey = await window.nostr.getPublicKey();
      console.log("Got public key:", pubkey);
      return pubkey;
    } catch (e) {
      console.error("Failed to get Nostr pubkey", e);
      alert("Failed to retrieve public key from Nostr: " + e.message);
    }
  }

  async login(event) {
    event.preventDefault();
    console.log("Login button clicked");
    
    // Disable button during login process
    if (this.hasLoginButtonTarget) {
      this.loginButtonTarget.disabled = true;
    }
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = "Requesting public key...";
    }
    
    try {
      const pubkey = await this.requestPublicKey();
      if (!pubkey) {
        if (this.hasLoginButtonTarget) {
          this.loginButtonTarget.disabled = false;
        }
        if (this.hasStatusTarget) {
          this.statusTarget.textContent = "Failed to get public key";
        }
        return;
      }
      
      if (this.hasStatusTarget) {
        this.statusTarget.textContent = "Logging in...";
      }
      
      // Send POST to /auth with the pubkey
      const response = await fetch("/auth", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.getMetaValue("csrf-token")
        },
        body: JSON.stringify({ public_key: pubkey })
      });
      
      const responseData = await response.json().catch(() => null);
      
      if (response.ok) {
        if (this.hasStatusTarget) {
          this.statusTarget.textContent = "Successfully logged in! Redirecting...";
          this.statusTarget.classList.remove("text-danger");
          this.statusTarget.classList.add("text-success");
        }
        // Store a flag in sessionStorage to show success message after reload
        sessionStorage.setItem('justLoggedIn', 'true');
        setTimeout(() => {
          window.location.href = '/';
        }, 1000);
      } else {
        console.error("Login failed", response.status, responseData);
        if (this.hasLoginButtonTarget) {
          this.loginButtonTarget.disabled = false;
        }
        if (this.hasStatusTarget) {
          this.statusTarget.textContent = "Login failed: " + (responseData?.error || response.statusText);
        }
        alert("Login failed: " + (responseData?.error || response.statusText));
      }
    } catch (error) {
      console.error("Login error:", error);
      if (this.hasLoginButtonTarget) {
        this.loginButtonTarget.disabled = false;
      }
      if (this.hasStatusTarget) {
        this.statusTarget.textContent = "Login error: " + error.message;
      }
      alert("Login error: " + error.message);
    }
  }


  getMetaValue(name) {
    const element = document.head.querySelector(`meta[name="${name}"]`);
    return element && element.getAttribute("content");
  }
}
