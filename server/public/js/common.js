/**
 * Shared dashboard helpers: API base, fetch JSON, WebSocket alerts.
 */
const API_BASE = '';

async function fetchJson(path) {
  const r = await fetch(`${API_BASE}${path}`);
  if (!r.ok) throw new Error(await r.text());
  return r.json();
}

function statusClass(fill) {
  if (fill < 50) return 'fill-low';
  if (fill <= 80) return 'fill-mid';
  return 'fill-high';
}

function connectAlertsFeed(onTick) {
  const proto = window.location.protocol === 'https:' ? 'wss' : 'ws';
  const ws = new WebSocket(`${proto}://${window.location.host}/ws`);
  ws.onmessage = (ev) => {
    try {
      const msg = JSON.parse(ev.data);
      if (msg.type === 'tick' && onTick) onTick(msg);
    } catch (_) {
      /* ignore */
    }
  };
  return ws;
}
