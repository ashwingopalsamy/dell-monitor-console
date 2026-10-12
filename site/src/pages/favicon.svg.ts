// The tab icon as vector, from the same geometry as the page's dial. The rays are a little bolder than the app
// icon's, because at 16 pixels the thin ones turn to grey.
import { rays, lit, DISK } from "../dial";

export const GET = () => {
  const on = lit(75);
  const lines = rays
    .map((r, i) => `<line x1="${r.x1}" y1="${r.y1}" x2="${r.x2}" y2="${r.y2}" stroke-width="${(r.width * 1.3).toFixed(2)}" stroke-opacity="${i < on ? 1 : 0.22}"/>`)
    .join("");
  const svg =
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">` +
    `<defs><linearGradient id="t" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#363636"/><stop offset="1" stop-color="#0e0e0e"/></linearGradient></defs>` +
    `<rect width="100" height="100" rx="22.4" fill="url(#t)"/>` +
    `<g stroke="#fff" stroke-linecap="round">${lines}</g>` +
    `<circle cx="50" cy="50" r="${DISK}" fill="#f4f4f4"/></svg>`;
  return new Response(svg, { headers: { "content-type": "image/svg+xml" } });
};
