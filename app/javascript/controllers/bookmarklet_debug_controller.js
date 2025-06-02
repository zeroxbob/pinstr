import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["statusMessage", "detectionLog", "testResults", "testOutput", "userAgent", "currentUrl", "extensionsList"]
  
  connect() {
    console.log("Bookmarklet debug controller connected")
    
    // Fill in browser info
    this.userAgentTarget.textContent = navigator.userAgent
    this.currentUrlTarget.textContent = window.location.href
    
    // Check for extensions
    this.checkExtensions()
    
    // Start continuous Nostr checking
    this.checkCount = 0
    this.continuousCheck()
  }

  log(message) {
    console.log(message)
    const logEntry = document.createElement('div')
    logEntry.className = 'log-entry'
    logEntry.textContent = new Date().toLocaleTimeString() + ': ' + message
    this.detectionLogTarget.appendChild(logEntry)
    this.detectionLogTarget.scrollTop = this.detectionLogTarget.scrollHeight
  }

  checkExtensions() {
    const extensions = []
    
    // Check for common extension objects
    if (window.nostr) extensions.push('Nostr (window.nostr)')
    if (window.webln) extensions.push('WebLN (window.webln)')
    if (window.ethereum) extensions.push('Ethereum (window.ethereum)')
    if (window.bitcoin) extensions.push('Bitcoin (window.bitcoin)')
    
    this.extensionsListTarget.textContent = extensions.length > 0 ? extensions.join(', ') : 'None detected'
  }

  checkNostr() {
    this.log('Starting Nostr check...')
    
    if (!window.nostr) {
      this.statusMessageTarget.textContent = 'No window.nostr object found'
      this.statusMessageTarget.className = 'status-error'
      this.log('window.nostr is not defined')
      return false
    }
    
    this.log('window.nostr found: ' + typeof window.nostr)
    this.log('window.nostr object: ' + JSON.stringify(Object.keys(window.nostr)))
    
    const hasPubkey = typeof window.nostr.getPublicKey === 'function'
    const hasSignEvent = typeof window.nostr.signEvent === 'function'
    
    this.log('getPublicKey method: ' + typeof window.nostr.getPublicKey)
    this.log('signEvent method: ' + typeof window.nostr.signEvent)
    
    if (hasPubkey && hasSignEvent) {
      this.statusMessageTarget.textContent = 'Nostr extension detected and ready!'
      this.statusMessageTarget.className = 'status-success'
      this.log('Nostr extension fully functional')
      return true
    } else {
      const missing = []
      if (!hasPubkey) missing.push('getPublicKey')
      if (!hasSignEvent) missing.push('signEvent')
      
      this.statusMessageTarget.textContent = 'Nostr extension missing methods: ' + missing.join(', ')
      this.statusMessageTarget.className = 'status-error'
      this.log('Nostr extension missing methods: ' + missing.join(', '))
      return false
    }
  }

  continuousCheck() {
    this.checkCount++
    this.log(`Continuous check #${this.checkCount}`)
    
    if (this.checkNostr()) {
      this.log('Nostr detected, stopping continuous checks')
      return
    }
    
    if (this.checkCount < 20) {
      setTimeout(() => this.continuousCheck(), 1000)
    } else {
      this.log('Gave up after 20 attempts')
    }
  }

  manualCheck() {
    this.log('Manual check requested')
    this.checkExtensions()
    this.checkNostr()
  }

  async testPubkey() {
    this.testResultsTarget.style.display = 'block'
    this.testOutputTarget.textContent = 'Testing getPublicKey...'
    
    if (!window.nostr || typeof window.nostr.getPublicKey !== 'function') {
      this.testOutputTarget.textContent = 'Error: getPublicKey not available'
      this.testOutputTarget.className = 'code-block error'
      return
    }
    
    try {
      const pubkey = await window.nostr.getPublicKey()
      this.testOutputTarget.textContent = 'Success: ' + pubkey
      this.testOutputTarget.className = 'code-block success'
      this.log('getPublicKey test successful: ' + pubkey)
    } catch (error) {
      this.testOutputTarget.textContent = 'Error: ' + error.message
      this.testOutputTarget.className = 'code-block error'
      this.log('getPublicKey test failed: ' + error.message)
    }
  }

  async testSigning() {
    this.testResultsTarget.style.display = 'block'
    this.testOutputTarget.textContent = 'Testing signEvent...'
    
    if (!window.nostr || typeof window.nostr.signEvent !== 'function' || typeof window.nostr.getPublicKey !== 'function') {
      this.testOutputTarget.textContent = 'Error: Required Nostr methods not available'
      this.testOutputTarget.className = 'code-block error'
      return
    }
    
    try {
      // Get pubkey first
      const pubkey = await window.nostr.getPublicKey()
      
      // Create a test event
      const testEvent = {
        kind: 1,
        pubkey: pubkey,
        created_at: Math.floor(Date.now() / 1000),
        tags: [],
        content: 'This is a test event from Pinstr debugging page.'
      }
      
      // Sign it
      const signedEvent = await window.nostr.signEvent(testEvent)
      
      // Display result
      this.testOutputTarget.textContent = JSON.stringify(signedEvent, null, 2)
      this.testOutputTarget.className = 'code-block success'
      this.log('signEvent test successful')
    } catch (error) {
      this.testOutputTarget.textContent = 'Error: ' + error.message
      this.testOutputTarget.className = 'code-block error'
      this.log('signEvent test failed: ' + error.message)
    }
  }
}