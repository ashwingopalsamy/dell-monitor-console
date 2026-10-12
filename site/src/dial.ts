// The app icon's dial, from AppIconRenderer.swift, so the page and the icon cannot drift apart.
// Everything is a fraction of the tile's width, drawn in a 100-unit box: eleven identical rays sweep 270 degrees from
// 7:30 round to 4:30, mirror-symmetric about the vertical axis, round a disk of radius .118. The lit rays are the level.
export const RAYS = 11;
export const DISK = 11.8;
export const GAP = 90 / 270; // the unlit arc at the bottom, as a fraction of the sweep

const INNER = 26.2;
const LENGTH = 9;
const WIDTH = 3.4;

export const rays = Array.from({ length: RAYS }, (_, i) => {
  const p = i / (RAYS - 1);
  const angle = ((225 - 270 * p) * Math.PI) / 180;
  const from = INNER;
  const to = INNER + LENGTH;
  // The icon is drawn with y up; SVG has y down.
  return {
    x1: +(50 + from * Math.cos(angle)).toFixed(2),
    y1: +(50 - from * Math.sin(angle)).toFixed(2),
    x2: +(50 + to * Math.cos(angle)).toFixed(2),
    y2: +(50 - to * Math.sin(angle)).toFixed(2),
    width: WIDTH,
  };
});

// The same rounding the icon uses: level 0...100 to how many of the eleven rays are lit.
export const lit = (level: number) => Math.round((level / 100) * RAYS);
