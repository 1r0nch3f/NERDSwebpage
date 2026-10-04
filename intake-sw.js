// Lets chattnerds.com/intake open with no internet (counter intake pad).
// Page: network first, saved copy when offline. Fonts: saved after first load.
// Form uploads are NOT handled here; the page queues them itself.
const CACHE = "nerds-intake-v1";

self.addEventListener("install", e => {
  e.waitUntil(caches.open(CACHE).then(c => c.add("intake.html")).then(() => self.skipWaiting()));
});

self.addEventListener("activate", e => {
  e.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(k => k.startsWith("nerds-intake-") && k !== CACHE).map(k => caches.delete(k))))
    .then(() => self.clients.claim()));
});

self.addEventListener("fetch", e => {
  const req = e.request;
  if (req.method !== "GET") return;
  if (req.mode === "navigate") {
    e.respondWith(fetch(req).then(r => {
      if (r.ok) { const copy = r.clone(); caches.open(CACHE).then(c => c.put("intake.html", copy)); }
      return r;
    }).catch(() => caches.match("intake.html")));
    return;
  }
  const host = new URL(req.url).hostname;
  if (host === "fonts.googleapis.com" || host === "fonts.gstatic.com") {
    e.respondWith(caches.match(req).then(hit => hit || fetch(req).then(r => {
      const copy = r.clone(); caches.open(CACHE).then(c => c.put(req, copy)); return r;
    })));
  }
});
