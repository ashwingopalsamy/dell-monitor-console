// The rest of a tab-and-home-screen icon set, made from the app's own icon layers in public/brand:
// favicon.ico (16, 32, 48) and a maskable PWA icon. The vector favicon.svg is an Astro endpoint, and
// the PNGs in public/ come from scripts/brand.sh in the app repository.
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { Resvg } from "@resvg/resvg-js";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const dist = join(root, "dist");
const png = (file) => `data:image/png;base64,${readFileSync(join(root, "public/brand", file)).toString("base64")}`;
const tile = png("tile-xl.png");
const glyph = png("glyph-xl.png");
const render = (svg, size) => new Resvg(svg, { fitTo: { mode: "width", value: size } }).render().asPng();

// The layers are 1280 px with the tile inset by 10% on every side, so the crop is the tile and nothing else.
const crop = (size) =>
  `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="128 128 1024 1024">` +
  `<image href="${tile}" width="1280" height="1280"/><image href="${glyph}" width="1280" height="1280"/></svg>`;

// An .ico is a small directory in front of PNG frames, which every current browser reads.
const sizes = [16, 32, 48];
const frames = sizes.map((s) => render(crop(s), s));
const head = Buffer.alloc(6 + 16 * sizes.length);
head.writeUInt16LE(1, 2);
head.writeUInt16LE(sizes.length, 4);
let offset = head.length;
sizes.forEach((s, i) => {
  const at = 6 + 16 * i;
  head.writeUInt8(s, at);
  head.writeUInt8(s, at + 1);
  head.writeUInt16LE(1, at + 4);
  head.writeUInt16LE(32, at + 6);
  head.writeUInt32LE(frames[i].length, at + 8);
  head.writeUInt32LE(offset, at + 12);
  offset += frames[i].length;
});
writeFileSync(join(dist, "favicon.ico"), Buffer.concat([head, ...frames]));

// Maskable: the tile's gradient runs to the edge so any mask shape stays dark, and the dial is scaled to sit inside
// the central 80% safe zone (its outer rays end at 32% of the canvas from the centre, a little under 40%).
const maskable =
  `<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">` +
  `<defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#363636"/><stop offset="1" stop-color="#0e0e0e"/></linearGradient></defs>` +
  `<rect width="512" height="512" fill="url(#g)"/><image href="${glyph}" x="-51.2" y="-51.2" width="614.4" height="614.4"/></svg>`;
writeFileSync(join(dist, "icon-maskable-512.png"), render(maskable, 512));
console.log("icons: favicon.ico, icon-maskable-512.png");
