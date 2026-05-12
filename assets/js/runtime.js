// runtime.js - Core utilities (lightweight version)
(function(w) {
  const VERSION = '2.1.0';
  const state = { initialized: false, config: null, routes: null };

  const listeners = new Map();
  function on(ev, cb) { (listeners.get(ev) || listeners.set(ev, []).get(ev)).push(cb); }
  function emit(ev, data) { (listeners.get(ev) || []).forEach(cb => { try { cb(data); } catch(e) {} }); }

  async function fetchJSON(url, opts={}) {
    const res = await fetch(url, opts);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    return res.json();
  }

  function getAssetUrl(p) { return p.startsWith('http') ? p : location.origin + (p.startsWith('/')?p:'/'+p); }

  function cacheGet(k) {
    try {
      const raw = localStorage.getItem(`rt_${k}`);
      if (!raw) return null;
      const { val, exp } = JSON.parse(raw);
      if (exp && Date.now() > exp) { localStorage.removeItem(`rt_${k}`); return null; }
      return val;
    } catch(e) { return null; }
  }
  function cacheSet(k, val, ttl=3600) {
    try { localStorage.setItem(`rt_${k}`, JSON.stringify({ val, exp: Date.now()+ttl*1000 })); } catch(e) {}
  }

  async function loadConfig() {
    state.config = await fetchJSON('/assets/data/cache.json');
    emit('config:loaded', state.config);
    return state.config;
  }
  async function loadRoutes() {
    state.routes = await fetchJSON('/assets/data/routes.json');
    emit('routes:loaded', state.routes);
    return state.routes;
  }

  async function init() {
    if (state.initialized) return;
    await Promise.all([loadConfig(), loadRoutes()]);
    state.initialized = true;
    emit('runtime:ready');
  }

  function getState() { return { ...state }; }

  w.__runtime = {
    version: VERSION, init, on, emit, getState, fetchJSON, getAssetUrl, cacheGet, cacheSet
  };
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
  else init();
})(window);