// The 1200x630 share card, dark and monochrome like the site: the claim, then the four figures. Drawn with satori
// and rasterised with resvg, from the numbers in docs/METRICS.md and the app's own icon layers.
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import satori from "satori";
import { Resvg } from "@resvg/resvg-js";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const dist = join(root, "dist");
const { facts, site } = JSON.parse(readFileSync(join(root, "src/generated/knowledge.json"), "utf8"));
const font = (weight) =>
  readFileSync(join(root, `node_modules/@fontsource/geist-sans/files/geist-sans-latin-${weight}-normal.woff`));
const fonts = [
  { name: "Geist", data: font(400), weight: 400, style: "normal" },
  { name: "Geist", data: font(600), weight: 600, style: "normal" },
];
const png = (file) => `data:image/png;base64,${readFileSync(join(root, "public/brand", file)).toString("base64")}`;
const tile = png("tile-xl.png");
const glyph = png("glyph-xl.png");

// Text never wraps: a figure that does not fit should be a smaller figure, not a broken card.
const el = (type, style, children) => ({ type, props: { style: { whiteSpace: "nowrap", ...style }, children } });
const row = (style, children) => el("div", { display: "flex", ...style }, children);
const layer = (src, size) => ({ type: "img", props: { src, width: size, height: size, style: { position: "absolute", left: 0, top: 0 } } });
const icon = (size) => row({ position: "relative", width: size, height: size }, [layer(tile, size), layer(glyph, size)]);

const figures = [
  [facts.size.ours, "installed"],
  [facts.memory.ours, "memory, idle"],
  [facts.cpu.ours, "CPU, idle"],
  [facts.permissions.ours === "none" ? "0" : facts.permissions.ours, "permissions"],
];

// A margin, not padding, keeps the 72px frame whatever box model the layout engine assumes.
const inner = row(
  { width: 1056, height: 486, margin: 72, flexDirection: "column", justifyContent: "space-between", fontFamily: "Geist" },
  [
    row({ alignItems: "center", justifyContent: "space-between" }, [
      row({ alignItems: "center", gap: 18 }, [
        icon(60),
        el("div", { display: "flex", fontSize: 28, fontWeight: 600, color: "#f5f5f7", letterSpacing: -0.5 }, site.name),
      ]),
      el("div", { display: "flex", fontSize: 22, color: "#6c6f76" }, "apps.ashwingopalsamy.in/dell-monitor-console"),
    ]),
    row({ alignItems: "center", justifyContent: "space-between" }, [
      row({ flexDirection: "column", gap: 20 }, [
        el("div", { display: "flex", flexDirection: "column", fontSize: 70, fontWeight: 600, letterSpacing: -3, lineHeight: 1.04 }, [
          el("div", { display: "flex", color: "#f5f5f7" }, "Display brightness,"),
          el("div", { display: "flex", color: "#a3a6ad" }, "and nothing else."),
        ]),
        el("div", { display: "flex", fontSize: 28, color: "#8a8d94" }, "A lite menu bar app for your Dell and other DDC/CI displays."),
      ]),
      icon(250),
    ]),
    row({ gap: 56 }, figures.map(([n, t]) =>
      row({ flexDirection: "column", gap: 2 }, [
        el("div", { display: "flex", fontSize: 44, fontWeight: 600, color: "#f7c243", letterSpacing: -1.5 }, n),
        el("div", { display: "flex", fontSize: 22, color: "#8a8d94" }, t),
      ]),
    )),
  ],
);
const card = row({ width: 1200, height: 630, background: "#0d0e10" }, [inner]);

mkdirSync(join(dist, "og"), { recursive: true });
const svg = await satori(card, { width: 1200, height: 630, fonts });
writeFileSync(join(dist, "og", "home.png"), new Resvg(svg, { fitTo: { mode: "width", value: 1200 } }).render().asPng());
console.log("og: 1 card");
