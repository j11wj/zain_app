/**
 * K-means clustering on bins using location + fill level (2D projected + scaled feature).
 */
const { kmeans } = require('ml-kmeans');

const DEFAULT_K = 3;

function clusterBins(bins, k = DEFAULT_K) {
  if (!bins.length) return { k: 0, clusters: [] };

  const lats = bins.map((b) => b.lat);
  const lngs = bins.map((b) => b.lng);

  const minLat = Math.min(...lats);
  const maxLat = Math.max(...lats);
  const minLng = Math.min(...lngs);
  const maxLng = Math.max(...lngs);

  const norm = (v, min, max) => (max === min ? 0 : (v - min) / (max - min));

  const data = bins.map((b) => [
    norm(b.lat, minLat, maxLat),
    norm(b.lng, minLng, maxLng),
    b.fill_level / 100,
  ]);

  const kk = Math.min(Math.max(1, k), bins.length);
  const ans = kmeans(data, kk, { initialization: 'kmeans++', maxIterations: 200 });

  const clusters = Array.from({ length: kk }, () => ({
    centroid: { lat: 0, lng: 0, fill_level: 0 },
    bins: [],
  }));

  for (let i = 0; i < bins.length; i++) {
    const c = ans.clusters[i];
    clusters[c].bins.push(bins[i]);
  }

  // Approximate centroids in real coordinates for map display
  for (let c = 0; c < kk; c++) {
    const list = clusters[c].bins;
    if (!list.length) continue;
    const sumLat = list.reduce((s, b) => s + b.lat, 0);
    const sumLng = list.reduce((s, b) => s + b.lng, 0);
    const sumFill = list.reduce((s, b) => s + b.fill_level, 0);
    clusters[c].centroid = {
      lat: sumLat / list.length,
      lng: sumLng / list.length,
      fill_level: sumFill / list.length,
    };
  }

  return {
    k: kk,
    clusters: clusters.map((cl, idx) => ({
      id: idx,
      centroid: cl.centroid,
      bins: cl.bins,
    })),
  };
}

module.exports = { clusterBins, DEFAULT_K };
