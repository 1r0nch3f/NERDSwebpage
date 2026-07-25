/* NERDS Messenger Chat Widget — m.me/chattnerds
   Drop this script on any page. It builds the entire widget in the DOM. */
(function () {
  if (document.getElementById('nerds-msg-wrap')) return; // already loaded

  var wrap = document.createElement('div');
  wrap.id = 'nerds-msg-wrap';
  wrap.innerHTML =
    '<style>' +
    '#nerds-msg-wrap{position:fixed;bottom:24px;right:24px;z-index:99999;font-family:Open Sans,Helvetica,Arial,sans-serif}' +
    '#nerds-msg-popup{position:absolute;bottom:72px;right:0;width:300px;background:#17181b;border:1px solid #2a2c31;border-radius:12px;padding:20px;box-shadow:0 8px 32px rgba(0,0,0,.5);opacity:0;visibility:hidden;transform:translateY(10px);transition:opacity .25s,visibility .25s,transform .25s}' +
    '#nerds-msg-popup.open{opacity:1;visibility:visible;transform:translateY(0)}' +
    '#nerds-msg-close{position:absolute;top:8px;right:12px;background:0 0;border:0;color:#888;font-size:18px;cursor:pointer;padding:4px}' +
    '#nerds-msg-title{color:#18C0D8;font-family:Oswald,sans-serif;text-transform:uppercase;letter-spacing:1px;font-size:15px;font-weight:700;margin:0 0 6px}' +
    '#nerds-msg-desc{color:#ccc;font-size:13px;line-height:1.5;margin:0 0 14px}' +
    '#nerds-msg-cta{display:block;text-align:center;background:#18C0D8;color:#0e0e10;font-weight:700;font-size:14px;padding:10px 0;border-radius:8px;text-decoration:none;transition:background .15s}' +
    '#nerds-msg-cta:hover{background:#15aac0}' +
    '#nerds-msg-bubble{width:56px;height:56px;background:#18C0D8;border-radius:50%;display:flex;align-items:center;justify-content:center;cursor:pointer;box-shadow:0 4px 16px rgba(24,192,216,.35);transition:transform .15s,box-shadow .15s;position:relative}' +
    '#nerds-msg-bubble:hover{transform:scale(1.08);box-shadow:0 6px 24px rgba(24,192,216,.5)}' +
    '#nerds-msg-badge{position:absolute;top:0;right:0;width:14px;height:14px;background:#e53935;border:2px solid #0e0e10;border-radius:50%}' +
    '@media(max-width:480px){#nerds-msg-popup{width:260px;right:-8px}}' +
    '</style>' +
    '<div id="nerds-msg-popup">' +
      '<button id="nerds-msg-close" aria-label="Close">&times;</button>' +
      '<p id="nerds-msg-title">Chat with NERDS</p>' +
      '<p id="nerds-msg-desc">Got a question about a build, repair, or service? Message us directly on Messenger.</p>' +
      '<a id="nerds-msg-cta" href="https://m.me/chattnerds" target="_blank" rel="noopener">Open Messenger</a>' +
    '</div>' +
    '<div id="nerds-msg-bubble" aria-label="Chat with us">' +
      '<div id="nerds-msg-badge"></div>' +
      '<svg viewBox="0 0 36 36" xmlns="http://www.w3.org/2000/svg" style="width:28px;height:28px;fill:#0e0e10">' +
        '<path d="M18 2C9.163 2 2 8.636 2 16.8c0 4.664 2.295 8.823 5.889 11.546v5.654l5.363-2.96A18.1 18.1 0 0018 31.6c8.837 0 16-6.636 16-14.8S26.837 2 18 2zm1.588 19.92l-4.08-4.36-7.96 4.36 8.76-9.28 4.18 4.36 7.86-4.36-8.76 9.28z"/>' +
      '</svg>' +
    '</div>';

  document.body.appendChild(wrap);

  var bubble = document.getElementById('nerds-msg-bubble');
  var popup = document.getElementById('nerds-msg-popup');
  var close = document.getElementById('nerds-msg-close');
  var badge = document.getElementById('nerds-msg-badge');
  var shown = false;

  bubble.addEventListener('click', function () {
    shown = !shown;
    popup.classList.toggle('open', shown);
    badge.style.display = 'none';
  });

  close.addEventListener('click', function (e) {
    e.stopPropagation();
    shown = false;
    popup.classList.remove('open');
  });

  document.addEventListener('click', function (e) {
    if (shown && !wrap.contains(e.target)) {
      shown = false;
      popup.classList.remove('open');
    }
  });

  // Auto-show after 5s on first visit per session
  if (!sessionStorage.getItem('nerds-msg-seen')) {
    setTimeout(function () {
      if (!shown) {
        shown = true;
        popup.classList.add('open');
        badge.style.display = 'none';
      }
      sessionStorage.setItem('nerds-msg-seen', '1');
    }, 5000);
  }
})();
