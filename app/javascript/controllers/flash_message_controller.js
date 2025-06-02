import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Check if user just logged in
    if (sessionStorage.getItem('justLoggedIn') === 'true') {
      sessionStorage.removeItem('justLoggedIn');
      this.showSuccessMessage('Successfully logged in with Nostr!');
    }
  }

  showSuccessMessage(message) {
    const flashContainer = document.createElement('div');
    flashContainer.className = 'flash notice';
    flashContainer.textContent = message;
    
    // Insert before main-content
    const mainContent = document.querySelector('.main-content');
    if (mainContent && mainContent.parentNode) {
      mainContent.parentNode.insertBefore(flashContainer, mainContent);
      
      // Auto-hide after 5 seconds
      setTimeout(() => {
        flashContainer.style.transition = 'opacity 0.5s';
        flashContainer.style.opacity = '0';
        setTimeout(() => flashContainer.remove(), 500);
      }, 5000);
    }
  }
}