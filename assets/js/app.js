// app.js - Main application logic, UI components, and routing integration
(function(window, runtime) {
  'use strict';

  const APP_VERSION = '1.4.2';
  const APP_BUILD = '2026-05-12T20:30:00.000Z';

  let currentRoute = null;
  let currentView = null;
  let viewContainer = null;
  let menuLinks = [];

  const viewCache = new Map();

  function getViewContainer() {
    if (!viewContainer) {
      viewContainer = document.querySelector('main');
      if (!viewContainer) {
        viewContainer = document.createElement('main');
        document.body.appendChild(viewContainer);
      }
    }
    return viewContainer;
  }

  async function loadView(routeId) {
    const routes = runtime.getState().routes;
    if (!routes || !routes.routes) {
      console.warn('Routes not loaded yet');
      return null;
    }
    const route = routes.routes.find(r => r.id === routeId);
    if (!route) return null;

    if (viewCache.has(routeId)) {
      return viewCache.get(routeId);
    }

    try {
      const module = await import(`./views/${route.component}`);
      const ViewClass = module.default;
      const viewInstance = new ViewClass(route, runtime);
      viewCache.set(routeId, viewInstance);
      return viewInstance;
    } catch (err) {
      console.error(`Failed to load view ${route.component}:`, err);
      return null;
    }
  }

  async function renderView(routeId) {
    const container = getViewContainer();
    if (currentView && typeof currentView.destroy === 'function') {
      currentView.destroy();
    }
    const view = await loadView(routeId);
    if (!view) {
      container.innerHTML = '<div class="error">View not found</div>';
      return;
    }
    currentView = view;
    if (typeof view.render === 'function') {
      const html = await view.render();
      container.innerHTML = html;
    }
    if (typeof view.attachEvents === 'function') {
      view.attachEvents();
    }
    runtime.emit('view:rendered', { routeId });
  }

  function updateActiveMenu(routeId) {
    menuLinks.forEach(link => {
      const href = link.getAttribute('href');
      const isActive = href === `/${routeId}` || (routeId === 'home' && href === '/');
      if (isActive) {
        link.classList.add('active');
        link.style.textShadow = '0 0 8px #0f0';
      } else {
        link.classList.remove('active');
        link.style.textShadow = '';
      }
    });
  }

  async function navigateTo(path) {
    const routes = runtime.getState().routes;
    if (!routes) return;

    let matchedRoute = null;
    let params = {};

    for (const route of routes.routes) {
      const routePath = route.path;
      if (routePath === path) {
        matchedRoute = route;
        break;
      }
      if (routePath !== '/' && path.startsWith(routePath)) {
        const remaining = path.slice(routePath.length);
        if (remaining === '' || remaining.startsWith('/') || remaining.startsWith('?')) {
          matchedRoute = route;
          break;
        }
      }
    }

    if (!matchedRoute) {
      matchedRoute = routes.routes.find(r => r.id === '404');
      if (!matchedRoute) return;
    }

    currentRoute = matchedRoute;
    document.title = matchedRoute.meta.title || 'Terminal';
    await renderView(matchedRoute.id);
    updateActiveMenu(matchedRoute.id);
    runtime.updatePerformanceMetrics('routeChanges', runtime.getState().performance.routeChanges + 1);
    window.history.pushState({ routeId: matchedRoute.id }, '', matchedRoute.path);
  }

  function handleLinkClick(e) {
    const link = e.target.closest('a');
    if (!link) return;
    const href = link.getAttribute('href');
    if (!href) return;
    if (href.startsWith('http') || href.startsWith('//')) return;
    if (href.startsWith('#')) return;

    e.preventDefault();
    navigateTo(href);
  }

  function initEventListeners() {
    document.body.addEventListener('click', handleLinkClick);
    window.addEventListener('popstate', (event) => {
      if (event.state && event.state.routeId) {
        const route = runtime.getState().routes?.routes.find(r => r.id === event.state.routeId);
        if (route) navigateTo(route.path);
      } else {
        navigateTo(window.location.pathname);
      }
    });
  }

  function initMenu() {
    menuLinks = Array.from(document.querySelectorAll('.menu a, header a, nav a'));
    menuLinks.forEach(link => {
      const href = link.getAttribute('href');
      if (href && (href.startsWith('/') || href === '/')) {
        link.addEventListener('click', (e) => {
          e.preventDefault();
          navigateTo(href);
        });
      }
    });
  }

  async function preloadNearbyRoutes(currentId) {
    const routes = runtime.getState().routes;
    if (!routes) return;
    const currentIndex = routes.routes.findIndex(r => r.id === currentId);
    if (currentIndex === -1) return;
    const nearby = [routes.routes[currentIndex - 1], routes.routes[currentIndex + 1]].filter(Boolean);
    for (const route of nearby) {
      if (route.lazy_load === false) continue;
      try {
        await import(`./views/${route.component}`);
      } catch(e) { /* silent */ }
    }
  }

  function initKeyboardShortcuts() {
    window.addEventListener('keydown', (e) => {
      if (e.ctrlKey && e.key === 'h') {
        e.preventDefault();
        navigateTo('/');
      }
      if (e.ctrlKey && e.key === 'p') {
        e.preventDefault();
        navigateTo('/profile');
      }
      if (e.ctrlKey && e.key === 'a') {
        e.preventDefault();
        navigateTo('/archive');
      }
      if (e.key === 'Escape') {
        const activeModal = document.querySelector('.modal.active');
        if (activeModal) activeModal.remove();
      }
    });
  }

  function initTheme() {
    const savedTheme = runtime.cacheGet('theme') || 'cyberpunk';
    document.body.setAttribute('data-theme', savedTheme);
    const style = document.createElement('style');
    style.textContent = `
      body[data-theme="cyberpunk"] { --neon-cyan: #0ff; --neon-amber: #FF9900; }
      body[data-theme="matrix"] { --neon-cyan: #0f0; --neon-amber: #afa; }
      body[data-theme="dark"] { --neon-cyan: #88f; --neon-amber: #fa0; }
    `;
    document.head.appendChild(style);
  }

  function initErrorHandling() {
    window.addEventListener('error', (event) => {
      runtime.emit('app:error', { message: event.message, filename: event.filename, lineno: event.lineno });
      console.error('Global error:', event.error);
    });
    window.addEventListener('unhandledrejection', (event) => {
      runtime.emit('app:error', { message: event.reason?.message || 'Unhandled promise rejection', stack: event.reason?.stack });
      console.error('Unhandled rejection:', event.reason);
    });
  }

  function initPerformanceObserver() {
    if (window.PerformanceObserver) {
      const observer = new PerformanceObserver((list) => {
        for (const entry of list.getEntries()) {
          if (entry.entryType === 'largest-contentful-paint') {
            runtime.updatePerformanceMetrics('lcp', entry.startTime);
          }
          if (entry.entryType === 'first-input') {
            runtime.updatePerformanceMetrics('fid', entry.processingStart - entry.startTime);
          }
        }
      });
      observer.observe({ entryTypes: ['largest-contentful-paint', 'first-input'] });
    }
  }

  function initCacheWarming() {
    const warmUrls = [
      '/assets/css/terminal.css',
      '/assets/data/routes.json',
      '/assets/content/entries.json'
    ];
    warmUrls.forEach(url => {
      fetch(url, { cache: 'force-cache' }).catch(() => {});
    });
  }

  function initServiceWorker() {
    if ('serviceWorker' in navigator && window.location.protocol === 'https:') {
      navigator.serviceWorker.register('/sw.js').catch(err => {
        console.warn('ServiceWorker registration failed:', err);
      });
    }
  }

  async function start() {
    runtime.on('runtime:ready', async () => {
      initEventListeners();
      initMenu();
      initKeyboardShortcuts();
      initTheme();
      initErrorHandling();
      initPerformanceObserver();
      initCacheWarming();
      initServiceWorker();

      const initialPath = window.location.pathname;
      await navigateTo(initialPath === '/' ? '/' : initialPath);

      runtime.emit('app:started', { version: APP_VERSION });
    });

    if (runtime.getState().initialized) {
      runtime.emit('runtime:ready');
    }
  }

  window.__app = {
    version: APP_VERSION,
    build: APP_BUILD,
    start,
    navigateTo,
    getCurrentRoute: () => currentRoute,
    preloadNearbyRoutes,
    reloadView: () => currentRoute && renderView(currentRoute.id)
  };

  start();
})(window, window.__runtime);