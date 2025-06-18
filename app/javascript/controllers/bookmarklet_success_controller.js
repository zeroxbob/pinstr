import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["countdown"]
  
  connect() {
    console.log("Bookmarklet success controller connected")
    
    // Check if we're in a popup window and start countdown
    this.isPopup = new URLSearchParams(window.location.search).get('popup') === 'true'
    
    if (this.isPopup && this.hasCountdownTarget) {
      this.startCountdown()
    }
  }
  
  startCountdown() {
    let countdown = 3
    
    const countdownInterval = setInterval(() => {
      countdown--
      if (this.hasCountdownTarget) {
        this.countdownTarget.textContent = countdown
      }
      
      if (countdown <= 0) {
        clearInterval(countdownInterval)
        console.log('⏰ Auto-closing popup window')
        this.closeWindow()
      }
    }, 1000)
  }
  
  closeWindow() {
    if (this.isPopup) {
      window.close()
    } else {
      // If not in popup, redirect to bookmarks page
      window.location.href = '/bookmarks'
    }
  }
}