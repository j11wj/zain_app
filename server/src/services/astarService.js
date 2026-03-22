/**
 * A* search for an open vehicle routing problem:
 * start at depot, visit every target bin exactly once (subset with fill >= threshold).
 * State: (currentRef, visitedMask) where currentRef is 'depot' or bin index in `targets`.
 * Heuristic: MST(lower bound) over unvisited + min distance from current to unvisited.
 */
const { haversineKm, mstTotalWeight } = require('./geoService');

function buildDistanceMatrix(depot, targets) {
  const n = targets.length;
  const depotTo = targets.map((t) => haversineKm(depot.lat, depot.lng, t.lat, t.lng));
  const between = Array.from({ length: n }, () => new Array(n).fill(0));
  for (let i = 0; i < n; i++) {
    for (let j = 0; j < n; j++) {
      if (i === j) continue;
      between[i][j] = haversineKm(targets[i].lat, targets[i].lng, targets[j].lat, targets[j].lng);
    }
  }
  return { depotTo, between };
}

/**
 * Admissible heuristic for remaining work.
 */
function heuristic(depot, targets, currentIsDepot, currentIdx, mask, n, depotTo, between) {
  const unvisited = [];
  for (let i = 0; i < n; i++) {
    if ((mask & (1 << i)) === 0) unvisited.push(i);
  }
  if (unvisited.length === 0) return 0;

  const pts = unvisited.map((i) => targets[i]);
  const mst = mstTotalWeight(pts);

  let minToUnvisited = Infinity;
  if (currentIsDepot) {
    for (const i of unvisited) minToUnvisited = Math.min(minToUnvisited, depotTo[i]);
  } else {
    for (const i of unvisited) {
      if (i === currentIdx) continue;
      minToUnvisited = Math.min(minToUnvisited, between[currentIdx][i]);
    }
  }
  if (!Number.isFinite(minToUnvisited)) minToUnvisited = 0;

  return mst + minToUnvisited;
}

/**
 * @returns {{ route: Array<{id:number,lat:number,lng:number,fill_level:number}>, totalDistanceKm: number, algorithm: string }}
 */
function computeOptimalCollectionRoute(depot, binsNeedingPickup) {
  const targets = binsNeedingPickup.map((b) => ({
    id: b.id,
    lat: b.lat,
    lng: b.lng,
    fill_level: b.fill_level,
  }));
  const n = targets.length;
  if (n === 0) {
    return { route: [], totalDistanceKm: 0, algorithm: 'A* (no targets)' };
  }
  if (n === 1) {
    const d = haversineKm(depot.lat, depot.lng, targets[0].lat, targets[0].lng);
    return { route: [targets[0]], totalDistanceKm: d, algorithm: 'A* (single stop)' };
  }

  const { depotTo, between } = buildDistanceMatrix(depot, targets);
  const fullMask = (1 << n) - 1;

  /** @type Map<string, number> */
  const bestG = new Map();

  function key(isDepot, idx, mask) {
    return `${isDepot ? 'D' : idx},${mask}`;
  }

  /** Priority queue: simple array + sort (n is small <= 15) */
  const open = [];

  function pushNode(node) {
    open.push(node);
    open.sort((a, b) => a.f - b.f);
  }

  const start = {
    isDepot: true,
    idx: -1,
    mask: 0,
    g: 0,
    f: heuristic(depot, targets, true, -1, 0, n, depotTo, between),
    path: [],
  };
  pushNode(start);
  bestG.set(key(true, -1, 0), 0);

  let bestGoal = null;

  while (open.length) {
    const cur = open.shift();
    if (!cur) break;

    const kcur = key(cur.isDepot, cur.idx, cur.mask);
    if (bestG.has(kcur) && cur.g > bestG.get(kcur) + 1e-6) continue;

    if (cur.mask === fullMask) {
      if (!bestGoal || cur.g < bestGoal.g) bestGoal = cur;
      continue;
    }

    const k = key(cur.isDepot, cur.idx, cur.mask);
    if (bestG.get(k) !== undefined && cur.g > bestG.get(k) + 1e-9) continue;

    for (let next = 0; next < n; next++) {
      if (cur.mask & (1 << next)) continue;

      let step = 0;
      if (cur.isDepot) step = depotTo[next];
      else step = between[cur.idx][next];

      const ng = cur.g + step;
      const nmask = cur.mask | (1 << next);
      const nk = key(false, next, nmask);

      if (bestG.has(nk) && bestG.get(nk) <= ng) continue;
      bestG.set(nk, ng);

      const nh = heuristic(depot, targets, false, next, nmask, n, depotTo, between);
      const nf = ng + nh;

      pushNode({
        isDepot: false,
        idx: next,
        mask: nmask,
        g: ng,
        f: nf,
        path: [...cur.path, targets[next]],
      });
    }
  }

  if (!bestGoal) {
    return { route: [], totalDistanceKm: 0, algorithm: 'A* (no path found)' };
  }

  return {
    route: bestGoal.path,
    totalDistanceKm: Math.round(bestGoal.g * 1000) / 1000,
    algorithm: 'A* (open TSP on full bins)',
  };
}

module.exports = { computeOptimalCollectionRoute };
