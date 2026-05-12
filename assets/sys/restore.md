# System Restore Protocol 

**Version:** 2.3.0  
**Last Updated:** 2026-05-12  
**Severity Levels:** Low | Medium | High | Critical


---

## 📋 Prerequisites

- Access to the repository root (`/` via GitHub Pages or local server)
- Console access (DevTools F12)
- Backup of `/assets/data/cache.json` and `/assets/data/routes.json`
- Git client (if restoring from origin)

---

## 🚨 Quick Recovery Commands


// Clear all runtime caches
localStorage.clear();

// Unregister service workers
navigator.serviceWorker.getRegistrations().then(regs => regs.forEach(r => r.unregister()));

// Force reload without cache
location.reload(true);