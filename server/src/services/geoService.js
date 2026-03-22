/**
 * Haversine distance (km) and helpers for routing heuristics.
 */

function haversineKm(lat1, lng1, lat2, lng2) {
  const R = 6371;
  const toRad = (d) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

/**
 * Prim's MST on complete graph; returns total edge weight (km).
 * @param {Array<{lat:number,lng:number}>} points
 */
function mstTotalWeight(points) {
  if (points.length <= 1) return 0;
  const n = points.length;
  const dist = (i, j) => haversineKm(points[i].lat, points[i].lng, points[j].lat, points[j].lng);

  const inTree = new Array(n).fill(false);
  const minEdge = new Array(n).fill(Infinity);
  minEdge[0] = 0;
  let total = 0;

  for (let iter = 0; iter < n; iter++) {
    let u = -1;
    let best = Infinity;
    for (let i = 0; i < n; i++) {
      if (!inTree[i] && minEdge[i] < best) {
        best = minEdge[i];
        u = i;
      }
    }
    if (u < 0) break;
    inTree[u] = true;
    total += minEdge[u] === Infinity ? 0 : minEdge[u];

    for (let v = 0; v < n; v++) {
      if (!inTree[v]) {
        const d = dist(u, v);
        if (d < minEdge[v]) minEdge[v] = d;
      }
    }
  }
  return total;
}

module.exports = { haversineKm, mstTotalWeight };
