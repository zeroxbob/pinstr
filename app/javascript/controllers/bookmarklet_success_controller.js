import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  closeWindow() {
    window.close()
  }
  
  openInNewTab(event) {
    // This will be handled by the target="_blank" on the link itself
    // But we can add any additional logic here if needed
  }
}