module ApplicationHelper
  # Generate the bookmarklet JavaScript code
  def bookmarklet_code
    # Base URL for the application (localhost for development)
    base_url = Rails.env.development? ? "http://localhost:3000" : request.base_url
    
    # Minified JavaScript code for the bookmarklet
    js_code = <<~JS.squish
      (function(){
        var d=document,
            w=window,
            e=w.getSelection,
            k=d.getSelection,
            x=d.selection,
            s=(e?e():(k)?k():(x?x.createRange().text:'')),
            l=d.location,
            e=encodeURIComponent,
            p='#{base_url}/bookmarklet?popup=true',
            u=e(l.href),
            t=e(d.title),
            z=e(s);
        function a(){
          if(!w.open(p+'&url='+u+'&title='+t+'&description='+z,'Pinstr','toolbar=no,scrollbars=yes,width=750,height=700'))
            l.href=p+'&url='+u+'&title='+t+'&description='+z;
        }
        if(/Firefox/.test(navigator.userAgent)) setTimeout(a,0); else a();
      })();
    JS
    
    # Return the minified code
    js_code
  end
  
  # Generate a version that's easier to read for debugging
  def bookmarklet_code_debug
    # Base URL for the application (localhost for development)
    base_url = Rails.env.development? ? "http://localhost:3000" : request.base_url
    
    # Readable JavaScript code for debugging
    <<~JS
      (function() {
        // Get the current document and window
        var doc = document;
        var win = window;
        
        // Get any selected text on the page
        var selection = '';
        if (win.getSelection) {
          selection = win.getSelection();
        } else if (doc.getSelection) {
          selection = doc.getSelection();
        } else if (doc.selection) {
          selection = doc.selection.createRange().text;
        }
        
        // Get current page URL and title
        var url = doc.location.href;
        var title = doc.title;
        
        // Encode parameters for the URL
        var encodeParam = encodeURIComponent;
        var bookmarkletUrl = '#{base_url}/bookmarklet?popup=true' +
                            '&url=' + encodeParam(url) +
                            '&title=' + encodeParam(title) +
                            '&description=' + encodeParam(selection);
        
        // Function to open popup window
        function openPopup() {
          // Try to open a popup window
          var popup = win.open(
            bookmarkletUrl,
            'Pinstr',
            'toolbar=no,scrollbars=yes,width=750,height=700'
          );
          
          // If popup is blocked, redirect instead
          if (!popup) {
            doc.location.href = bookmarkletUrl;
          }
        }
        
        // Firefox needs a setTimeout to work properly
        if (/Firefox/.test(navigator.userAgent)) {
          setTimeout(openPopup, 0);
        } else {
          openPopup();
        }
      })();
    JS
  end
end
