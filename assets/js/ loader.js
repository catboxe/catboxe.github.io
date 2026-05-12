// runtime.js - Core runtime utilities and global state management
(function(window) {
  'use strict';

  const RUNTIME_VERSION = '2.1.4';
  const BUILD_TIMESTAMP = '2026-05-12T20:15:30.123Z';

  const globalState = {
    initialized: false,
    config: null,
    routes: null,
    cache: null,
    user: {
      isLoggedIn: false,
      role: 'guest',
      preferences: {
        theme: 'cyberpunk',
        animations: true,
        soundEnabled: false
      }
    },
    performance: {
      navigationStart: performance.now(),
      routeChanges: 0,
      cacheHits: 0,
      cacheMisses: 0
    },
    featureFlags: {
      webgl: false,
      experimentalCss: true,
      preconnect: true
    }
  };

  const subscribers = new Map();

  function emit(event, data) {
    if (subscribers.has(event)) {
      subscribers.get(event).forEach(cb => {
        try { cb(data); } catch(e) { console.warn(e); }
      });
    }
  }

  function on(event, callback) {
    if (!subscribers.has(event)) subscribers.set(event, []);
    subscribers.get(event).push(callback);
    return () => {
      const list = subscribers.get(event);
      if (list) {
        const idx = list.indexOf(callback);
        if (idx !== -1) list.splice(idx, 1);
      }
    };
  }

  async function fetchJSON(url, options = {}) {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), options.timeout || 10000);
    try {
      const response = await fetch(url, { ...options, signal: controller.signal });
      clearTimeout(timeoutId);
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const data = await response.json();
      return data;
    } catch (err) {
      clearTimeout(timeoutId);
      console.error(`Failed to fetch ${url}:`, err);
      throw err;
    }
  }

  function getAssetUrl(path) {
    if (path.startsWith('http')) return path;
    const base = window.location.origin;
    return base + (path.startsWith('/') ? path : '/' + path);
  }

  function cacheGet(key) {
    try {
      const item = localStorage.getItem(`runtime_${key}`);
      if (!item) return null;
      const parsed = JSON.parse(item);
      if (parsed.expiry && Date.now() > parsed.expiry) {
        localStorage.removeItem(`runtime_${key}`);
        return null;
      }
      return parsed.value;
    } catch(e) { return null; }
  }

  function cacheSet(key, value, ttlSeconds = 3600) {
    try {
      const expiry = Date.now() + (ttlSeconds * 1000);
      localStorage.setItem(`runtime_${key}`, JSON.stringify({ value, expiry }));
    } catch(e) { console.warn('Cache set failed', e); }
  }

  async function loadConfig() {
    try {
      const data = await fetchJSON('/assets/data/cache.json');
      globalState.config = data;
      emit('config:loaded', data);
      return data;
    } catch (err) {
      console.error('Failed to load cache.json', err);
      throw err;
    }
  }

  async function loadRoutes() {
    try {
      const data = await fetchJSON('/assets/data/routes.json');
      globalState.routes = data;
      emit('routes:loaded', data);
      return data;
    } catch (err) {
      console.error('Failed to load routes.json', err);
      throw err;
    }
  }

  function updatePerformanceMetrics(metric, value) {
    if (globalState.performance.hasOwnProperty(metric)) {
      globalState.performance[metric] = value;
      emit('performance:update', { metric, value });
    }
  }

  function getState() {
    return { ...globalState };
  }

  function setUserPreference(key, value) {
    globalState.user.preferences[key] = value;
    emit('user:preference', { key, value });
    cacheSet(`user_pref_${key}`, value, 86400);
  }

  async function initialize() {
    if (globalState.initialized) return;
    try {
      await Promise.all([loadConfig(), loadRoutes()]);
      globalState.initialized = true;
      emit('runtime:ready', { version: RUNTIME_VERSION });
      return true;
    } catch (err) {
      emit('runtime:error', err);
      throw err;
    }
  }

  window.__runtime = {
    version: RUNTIME_VERSION,
    build: BUILD_TIMESTAMP,
    init: initialize,
    on,
    emit,
    getState,
    fetchJSON,
    getAssetUrl,
    cacheGet,
    cacheSet,
    updatePerformanceMetrics,
    setUserPreference
  };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => initialize().catch(console.warn));
  } else {
    initialize().catch(console.warn);
  }
})(window);