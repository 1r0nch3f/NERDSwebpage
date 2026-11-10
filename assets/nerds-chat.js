/* NERDS chat bubble (NERD Brain). Replaces the Tawk look with our own.
   Shows only when the chat server answers its health check; otherwise stays hidden and Tawk keeps working.
   Server: nerd-ai (my-agent/nerds-chat). Vault: NERDS Website Chat. */
(function () {
  if (window.__nerdsChat) return; window.__nerdsChat = 1;
  var LOCAL = /^(127\.0\.0\.1|localhost)$/.test(location.hostname);
  var API = window.NERDS_CHAT_URL || (LOCAL ? "http://192.168.1.247:8760" : "https://chat.chattnerds.net");
  var PHONE = "423-521-5694", SMS = "sms:+14235215694", TEL = "tel:+14235215694";
  var MASCOT = "assets/nerds-wink.png";
  var GREET = "Hey! I'm NERD Brain, the NERDS AI assistant. What can I help you with today?";

  function store(k, v) { try { if (v === undefined) return sessionStorage.getItem(k); sessionStorage.setItem(k, v); } catch (e) { return null; } }
  function sid() {
    var s = store("nerdsChatSid");
    if (!s) { s = "w-" + Date.now().toString(36) + "-" + Math.random().toString(36).slice(2, 10); store("nerdsChatSid", s); }
    return s;
  }

  var css = [
    ".nc-btn{position:fixed;right:20px;bottom:20px;z-index:2147483000;display:flex;align-items:center;gap:10px;padding:8px 18px 8px 8px;border:0;border-radius:999px;cursor:pointer;",
    "background:#0c0d11;color:#fff;font:700 15px Oswald,Impact,sans-serif;letter-spacing:1px;text-transform:uppercase;",
    "box-shadow:0 0 0 2px #18C0D8,0 12px 40px -6px rgba(24,192,216,.75);transition:transform .15s}",
    ".nc-btn:hover{transform:translateY(-2px)}.nc-btn img{width:44px;height:44px;border-radius:50%;background:#12131a}",
    ".nc-btn .nc-dot{width:9px;height:9px;border-radius:50%;background:#28B848;box-shadow:0 0 8px #28B848}",
    ".nc-panel{position:fixed;right:20px;bottom:20px;z-index:2147483001;width:380px;max-width:calc(100vw - 24px);height:560px;max-height:calc(100vh - 40px);",
    "display:none;flex-direction:column;border-radius:22px;overflow:hidden;background:#0c0d11;border:1px solid #23252e;",
    "box-shadow:0 30px 80px -20px rgba(0,0,0,.9),0 0 0 1px rgba(24,192,216,.35);font:15px/1.5 'Open Sans',system-ui,sans-serif;color:#e9ebef}",
    ".nc-panel.open{display:flex}",
    ".nc-head{display:flex;align-items:center;gap:12px;padding:14px 16px;background:linear-gradient(120deg,rgba(24,192,216,.22),rgba(192,44,216,.18));border-bottom:1px solid #23252e}",
    ".nc-head img{width:42px;height:42px;border-radius:50%;background:#12131a}",
    ".nc-head b{display:block;font:700 18px Oswald,sans-serif;letter-spacing:1px;text-transform:uppercase;color:#fff}",
    ".nc-head small{color:#a3a8b4;font-size:12px}.nc-head small i{display:inline-block;width:7px;height:7px;border-radius:50%;background:#28B848;margin-right:5px}",
    ".nc-x{margin-left:auto;background:none;border:0;color:#a3a8b4;font-size:26px;line-height:1;cursor:pointer;padding:4px 8px}.nc-x:hover{color:#fff}",
    ".nc-log{flex:1;overflow-y:auto;padding:16px;display:flex;flex-direction:column;gap:10px}",
    ".nc-m{max-width:85%;padding:10px 14px;border-radius:16px;white-space:pre-wrap;word-wrap:break-word}",
    ".nc-bot{align-self:flex-start;background:#17181f;border:1px solid #23252e;border-bottom-left-radius:4px}",
    ".nc-me{align-self:flex-end;background:#18C0D8;color:#00161a;border-bottom-right-radius:4px}",
    ".nc-typing{align-self:flex-start;color:#a3a8b4;font-size:13px;padding:4px 6px}",
    ".nc-chips{display:flex;flex-wrap:wrap;gap:6px;padding:0 16px 10px}",
    ".nc-chips button{border:1px solid #23252e;background:#12131a;color:#d7dae1;border-radius:999px;padding:7px 12px;font:600 13px 'Open Sans',sans-serif;cursor:pointer}",
    ".nc-chips button:hover{border-color:#18C0D8}",
    ".nc-form{display:flex;gap:8px;padding:12px;border-top:1px solid #23252e;background:#0a0b0e}",
    ".nc-form input{flex:1;min-width:0;padding:12px 14px;border-radius:999px;border:1px solid #23252e;background:#12131a;color:#fff;font:15px 'Open Sans',sans-serif}",
    ".nc-form input:focus{outline:none;border-color:#18C0D8}",
    ".nc-form button{border:0;border-radius:999px;padding:0 18px;background:#D80018;color:#fff;font:700 14px Oswald,sans-serif;letter-spacing:1px;text-transform:uppercase;cursor:pointer}",
    ".nc-form button:disabled{opacity:.5;cursor:wait}",
    ".nc-foot{display:flex;gap:6px;padding:0 12px 12px;background:#0a0b0e}",
    ".nc-foot a{flex:1;text-align:center;padding:8px 4px;border-radius:10px;border:1px solid #23252e;color:#d7dae1;text-decoration:none;font:600 12px 'Open Sans',sans-serif}",
    ".nc-foot a:hover{border-color:#18C0D8;color:#fff}",
    ".nc-note{padding:0 12px 10px;background:#0a0b0e;color:#6e7380;font-size:11px;text-align:center}",
    "@media (max-width:520px){.nc-panel{right:0;bottom:0;width:100vw;max-width:100vw;height:100%;max-height:100%;border-radius:0}",
    ".nc-btn{right:14px;bottom:14px;padding:6px 14px 6px 6px}.nc-btn img{width:38px;height:38px}}"
  ].join("");

  function el(tag, cls, html) { var e = document.createElement(tag); if (cls) e.className = cls; if (html != null) e.innerHTML = html; return e; }

  function build() {
    var st = el("style"); st.textContent = css; document.head.appendChild(st);
    var btn = el("button", "nc-btn", '<img src="' + MASCOT + '" alt=""><span>Chat with us</span><span class="nc-dot"></span>');
    btn.setAttribute("aria-label", "Open chat with NERD Brain");
    var p = el("div", "nc-panel");
    p.setAttribute("role", "dialog"); p.setAttribute("aria-label", "Chat with NERD Brain");
    p.innerHTML =
      '<div class="nc-head"><img src="' + MASCOT + '" alt=""><div><b>NERD Brain</b><small><i></i>NERDS AI assistant, replies in seconds</small></div>' +
      '<button class="nc-x" aria-label="Close chat">&times;</button></div>' +
      '<div class="nc-log" aria-live="polite"></div>' +
      '<div class="nc-chips"><button>My computer needs fixing</button><button>Custom PC quote</button><button>Business IT</button><button>What are your prices?</button></div>' +
      '<form class="nc-form"><input type="text" maxlength="600" placeholder="Type a message..." aria-label="Message"><button type="submit">Send</button></form>' +
      '<div class="nc-foot"><a href="' + SMS + '">Text us</a><a href="' + TEL + '">Call</a><a href="quote.html">Get a quote</a></div>' +
      '<div class="nc-note">AI assistant. Mike follows up with you personally.</div>';
    document.body.appendChild(btn); document.body.appendChild(p);

    var log = p.querySelector(".nc-log"), form = p.querySelector(".nc-form"), input = form.querySelector("input"),
        send = form.querySelector("button"), chips = p.querySelector(".nc-chips"), busy = false;

    function add(text, who) { var m = el("div", "nc-m " + (who === "me" ? "nc-me" : "nc-bot")); m.textContent = text; log.appendChild(m); log.scrollTop = log.scrollHeight; return m; }
    function history() { try { return JSON.parse(store("nerdsChatLog") || "[]"); } catch (e) { return []; } }
    function remember(text, who) { var h = history(); h.push([who, text]); store("nerdsChatLog", JSON.stringify(h.slice(-40))); }
    function restore() { var h = history(); if (!h.length) { add(GREET, "bot"); return; } h.forEach(function (x) { add(x[1], x[0]); }); chips.style.display = "none"; }

    function talk(text) {
      text = (text || "").trim(); if (!text || busy) return;
      busy = true; send.disabled = true; chips.style.display = "none";
      add(text, "me"); remember(text, "me"); input.value = "";
      var t = el("div", "nc-typing", "NERD Brain is typing..."); log.appendChild(t); log.scrollTop = log.scrollHeight;
      var ctl = window.AbortController ? new AbortController() : null, timer = setTimeout(function () { if (ctl) ctl.abort(); }, 45000);
      fetch(API + "/api/chat", { method: "POST", headers: { "Content-Type": "application/json" }, signal: ctl ? ctl.signal : undefined,
        body: JSON.stringify({ sid: sid(), msg: text, page: location.pathname }) })
        .then(function (r) { if (!r.ok) throw 0; return r.json(); })
        .then(function (j) { t.remove(); add(j.reply, "bot"); remember(j.reply, "bot"); })
        .catch(function () { t.remove(); add("Sorry, I lost my connection. Text Mike at " + PHONE + " and he'll get right back to you.", "bot"); })
        .then(function () { clearTimeout(timer); busy = false; send.disabled = false; input.focus(); });
    }

    function open() { p.classList.add("open"); btn.style.display = "none"; if (!log.childNodes.length) restore(); setTimeout(function () { input.focus(); }, 50); }
    function close() { p.classList.remove("open"); btn.style.display = ""; btn.focus(); }
    btn.addEventListener("click", open);
    p.querySelector(".nc-x").addEventListener("click", close);
    document.addEventListener("keydown", function (e) { if (e.key === "Escape" && p.classList.contains("open")) close(); });
    form.addEventListener("submit", function (e) { e.preventDefault(); talk(input.value); });
    chips.addEventListener("click", function (e) { if (e.target.tagName === "BUTTON") talk(e.target.textContent); });
    window.NERDSChat = { open: open, close: close };
  }

  function hideTawk() {
    window.Tawk_API = window.Tawk_API || {};
    var hide = function () { try { window.Tawk_API.hideWidget(); } catch (e) {} };
    var prev = window.Tawk_API.onLoad;
    window.Tawk_API.onLoad = function () { if (prev) try { prev(); } catch (e) {} hide(); };
    hide();
  }

  function start() {
    var ctl = window.AbortController ? new AbortController() : null, timer = setTimeout(function () { if (ctl) ctl.abort(); }, 5000);
    fetch(API + "/health", { signal: ctl ? ctl.signal : undefined })
      .then(function (r) { clearTimeout(timer); if (!r.ok) throw 0; hideTawk(); build(); })
      .catch(function () { clearTimeout(timer); /* server unreachable: stay hidden, Tawk keeps working */ });
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start); else start();
})();
