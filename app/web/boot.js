// Boot helpers (kept out of index.html so the CSP needs no 'unsafe-inline' for scripts).
    window.addEventListener('flutter-first-frame', function(){var s=document.getElementById('splash');s.style.opacity=0;setTimeout(function(){s.remove()},450);});
    // Offline: cache the app shell + assets (no network needed after first load).
    // Reset only this app's scope. Never unregister a neighbor app's worker.
    var appScope = new URL(document.baseURI), cachePrefix = 'thetoms:' + appScope.pathname + ':';
    function ownRegistration(r) { return r.scope === appScope.href; }
    if (/[?&#]reset\b/.test(location.href) && 'serviceWorker' in navigator) {
      Promise.all([navigator.serviceWorker.getRegistrations().then(function(rs){ return Promise.all(rs.filter(ownRegistration).map(function(r){ return r.unregister(); })); }),
        window.caches ? caches.keys().then(function(ks){ return Promise.all(ks.filter(function(k){ return k.indexOf(cachePrefix) === 0; }).map(function(k){ return caches.delete(k); })); }) : null])
        .then(function(){ location.replace(location.pathname); });
    } else if ('serviceWorker' in navigator) window.addEventListener('load', function(){
      // Any leftover worker that isn't sw.js (e.g. an old flutter_service_worker.js) is removed.
      function offlineUnavailable(error) { console.warn('Offline cache is unavailable in this browser session.', error); }
      navigator.serviceWorker.getRegistrations().then(function(rs){ rs.filter(ownRegistration).forEach(function(r){ var w = r.active || r.waiting || r.installing; if (w && !/\/sw\.js(\?|$)/.test(w.scriptURL)) r.unregister().catch(offlineUnavailable); }); }).catch(offlineUnavailable);
      navigator.serviceWorker.register('sw.js', {updateViaCache: 'none'}).then(function(r){
        if (!r) return;
        function checkUpdate() { Promise.resolve().then(function(){ return r.update(); }).catch(offlineUnavailable); }
        checkUpdate();
        document.addEventListener('visibilitychange', function(){ if (document.visibilityState === 'visible') checkUpdate(); });
      }).catch(offlineUnavailable);
    });
    // A new deploy's worker takes over → reload once so the fresh app code runs (never stale JS).
    if ('serviceWorker' in navigator) { var hadController = !!navigator.serviceWorker.controller, reloaded = false;
      navigator.serviceWorker.addEventListener('controllerchange', function(){ if (hadController && !reloaded) { reloaded = true; location.reload(); } }); }
