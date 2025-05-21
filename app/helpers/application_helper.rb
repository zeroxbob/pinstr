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
end
