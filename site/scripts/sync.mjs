// Turns the repository's docs into the page's section bodies and one knowledge file. Runs before dev and build.
// docs/*.md stay the source of truth, including every number on the page: nothing here is edited by hand, and a
// row the page relies on that is missing from docs/METRICS.md fails the build instead of printing a stale figure.
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const repo = join(root, "..");
const ORIGIN = "https://apps.ashwingopalsamy.in";
const BASE = "/dell-monitor-console";
const GH = "https://github.com/ashwingopalsamy/dell-monitor-console";

// release.json is the one switch between "not released yet, build it" and "download it, brew it, or build it".
// While the version is null nothing offers a DMG or a Homebrew command, because neither exists.
const { version } = JSON.parse(readFileSync(join(root, "release.json"), "utf8"));
if (version !== null && !/^\d+\.\d+\.\d+$/.test(version)) throw new Error('site/release.json: "version" is null or "x.y.z"');
const released = version !== null;
const release = released
  ? {
      version,
      brew: "brew install --cask ashwingopalsamy/tap/dell-monitor-console",
      dmgName: `Dell-Monitor-Console-${version}.dmg`,
      dmgUrl: `${GH}/releases/download/v${version}/Dell-Monitor-Console-${version}.dmg`,
      url: `${GH}/releases/latest`,
    }
  : null;
// In a doc, <!-- unreleased --> text shows only before the first release, and <!-- released ... --> text only after
// it. The released blocks sit inside a comment so the document reads correctly on GitHub today.
const gate = (md) =>
  md
    .replace(/<!-- released\n([\s\S]*?)\/released -->\n?/g, (_, body) => (released ? body : ""))
    .replace(/<!-- unreleased -->\n([\s\S]*?)<!-- \/unreleased -->\n?/g, (_, body) => (released ? "" : body))
    .replaceAll("{{version}}", version ?? "");

// A page is one document. A section is the part of a page that one block of the site renders.
const pages = [
  { slug: "metrics", src: "docs/METRICS.md", title: "By the numbers", anchor: "#numbers",
    description: "Measured on one M4 Pro Mac with a Dell U2723QE and a U2424HE, on 2026-10-11 and 12. Dell's app, Display and Peripheral Manager 2.3 (DDPM), was launched once, sampled and quit; its install size and history come from its files and its own log." },
  { slug: "how-it-works", src: "docs/HOW-IT-WORKS.md", title: "How it works", anchor: "#control",
    description: "One slider per display: real backlight where a display answers DDC/CI, a software dim where it does not, macOS for the built-in panel. Every request goes twice and every reply is validated." },
  { slug: "privacy", src: "docs/PRIVACY.md", title: "Privacy", anchor: "#privacy",
    description: "No network, no permissions, no telemetry, and the commands to check it yourself." },
  { slug: "install", src: "docs/INSTALL.md", title: "Install", anchor: "#install",
    description: released
      ? "Homebrew, the DMG, or from source. Needs macOS 26 on Apple silicon."
      : "Clone, run scripts/bundle.sh, open the app. Needs macOS 26 on Apple silicon." },
];
// Which H2 blocks of which page a section shows. A section with no list is the whole page, intro included.
const sections = {
  numbers: { page: "metrics", only: ["Footprint", "Runtime, side by side", "Background activity", "What each asks of you"] },
  latency: { page: "metrics", only: ["Latency of one DDC/CI exchange"] },
  unmeasured: { page: "metrics", only: ["What is not measured"] },
  more: { page: "metrics", only: ["Where DDPM does more"] },
  control: { page: "how-it-works", only: ["How each display is controlled"] },
  twice: { page: "how-it-works", only: ["Why every request goes twice"] },
  privacy: { page: "privacy" },
  install: { page: "install" },
};
const ledes = {
  control: "One slider per display. Real backlight where a display answers DDC/CI, a software dim where it does not, macOS for the built-in panel.",
  twice: "Forty milliseconds apart, because DDC/CI asks for at least that long between commands.",
};

// Where a docs link lands on the single page. Anything else links to the repository.
const slugBySource = { "PRIVACY.md": "privacy", "INSTALL.md": "install", "METRICS.md": "metrics", "HOW-IT-WORKS.md": "how-it-works" };
function rewriteLinks(md) {
  return md.replace(/\]\((?!https?:|#|\/|mailto:)([^)]+)\)/g, (_, target) => {
    const [path, hash] = target.split("#");
    const name = path.replace(/^(\.\.\/|\.\/)+/, "").replace(/^docs\//, "");
    const page = pages.find((p) => p.slug === slugBySource[name]);
    if (page) return `](${BASE}/${page.anchor})`;
    return `](${GH}/blob/main/${path.replace(/^(\.\.\/|\.\/)+/, "")}${hash ? "#" + hash : ""})`;
  });
}

// Shell blocks are highlighted here, at build time, so the page needs no script and no highlighter dependency.
const esc = (t) => t.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
const attr = (t) => esc(t).replace(/"/g, "&quot;").replace(/\n/g, "&#10;");
const span = (cls, t) => `<span class="${cls}">${esc(t)}</span>`;
function highlightLine(line) {
  if (/^\s*#/.test(line)) return span("o", line);
  const hash = line.search(/\s#\s/);
  if (hash > 0) return highlightLine(line.slice(0, hash)) + span("o", line.slice(hash));
  const token = /("(?:[^"\\]|\\.)*"|'[^']*')|(&&|\|\||\||;|\\$)|(\s+)|([^\s"'|&;]+)/g;
  let out = "";
  let command = true;
  for (const m of line.matchAll(token)) {
    if (m[1]) {
      out += m[1].startsWith("'")
        ? span("s", m[1])
        : m[1].split(/(\$\([^)]*\)|\$\{[^}]*\}|\$[A-Za-z_]+)/).map((part, i) => (i % 2 ? span("v", part) : part ? span("s", part) : "")).join("");
      command = false;
    } else if (m[2]) {
      out += span("o", m[2]);
      if (m[2] !== "\\") command = true;
    } else if (m[3]) {
      out += m[3];
    } else {
      const w = m[4];
      out += span(command ? "c" : w.startsWith("-") ? "f" : /^\d+$/.test(w) ? "v" : /[\/.*]/.test(w) ? "u" : "a", w);
      command = false;
    }
  }
  return out;
}
const icon = (cls, d) =>
  `<svg class="${cls}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${d}</svg>`;
// One line of HTML on purpose: a blank line inside a raw HTML block would end it and hand the rest to Markdown.
// The copied text drops comments, because an interactive zsh does not treat # as one.
const highlightFences = (md) =>
  md.replace(/```(?:sh|bash|shell)\n([\s\S]*?)```/g, (_, code) => {
    const lines = code.replace(/\n$/, "").split("\n");
    const copy = lines.filter((l) => l.trim() && !/^\s*#/.test(l)).map((l) => l.replace(/\s+#\s.*$/, "")).join("\n");
    return (
      `<div class="shell"><pre class="code" tabindex="0"><code>${lines.map(highlightLine).join("&#10;")}</code></pre>` +
      `<button class="cp" type="button" data-copy="${attr(copy)}" aria-label="Copy these commands">` +
      icon("ic", '<rect x="8.5" y="8.5" width="11" height="11" rx="2.5"/><path d="M15.5 8.5v-2a2 2 0 0 0-2-2h-7a2 2 0 0 0-2 2v7a2 2 0 0 0 2 2h2"/>') +
      icon("ok", '<path d="M5 12.5l4.5 4.5L19 7.5"/>') +
      `</button></div>`
    );
  });

// Pipe tables. The page gets real HTML with data-label attributes, so a table can fold into stacked rows on a phone;
// the knowledge file gets the same cells as plain text.
const TABLE = /^\|.+\|\n\|[\s|:-]+\|\n(?:\|.+\|(?:\n|$))+/gm;
const cells = (row) => row.trim().replace(/^\||\|$/g, "").split("|").map((c) => c.trim());
const plain = (s) => s.replace(/\*\*/g, "").replace(/`/g, "");
const inline = (s) => esc(s).replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>").replace(/`([^`]+)`/g, "<code>$1</code>");
function tableHtml(block) {
  const [head, , ...body] = block.trim().split("\n");
  const cols = cells(head);
  const th = cols.map((c, i) => `<th scope="col">${c ? inline(c) : `<span class="sr">${i ? "Note" : "Item"}</span>`}</th>`).join("");
  const rows = body
    .map((line) => {
      const [first, ...rest] = cells(line);
      const tds = rest.map((c, i) => `<td data-label="${attr(plain(cols[i + 1] || ""))}">${inline(c)}</td>`).join("");
      return `<tr><th scope="row">${inline(first)}</th>${tds}</tr>`;
    })
    .join("");
  return `<div class="tbl"><table><thead><tr>${th}</tr></thead><tbody>${rows}</tbody></table></div>`;
}

// The intro first (empty when the document opens with a heading), then one block per H2.
const blocks = (md) => {
  const parts = md.split(/^(?=## )/m);
  return parts[0].startsWith("## ") ? ["", ...parts] : parts;
};
const title = (block) => block.match(/^## (.*)/)?.[1];
const withoutH1 = (md) => md.replace(/^# .*\n+/, "");

function render(md, { single }) {
  let out = rewriteLinks(md);
  // A section of one block is titled by the page, so its own H2 goes and its H3s stay H3. Otherwise H2 becomes H3.
  out = single ? out.replace(/^## .*\n+/, "") : out.replace(/^(#{2,5}) /gm, "#$1 ");
  return highlightFences(out.replace(TABLE, (t) => `${tableHtml(t)}\n`));
}

mkdirSync(join(root, "src/generated"), { recursive: true });
mkdirSync(join(root, "src/content-md"), { recursive: true });

const docs = {};
const knowledge = { pages: [], faq: [], metrics: { tables: [] } };
for (const page of pages) {
  const raw = gate(withoutH1(readFileSync(join(repo, page.src), "utf8")));
  docs[page.slug] = raw;
  knowledge.pages.push({
    slug: page.slug,
    url: `${BASE}/`,
    anchor: page.anchor,
    title: page.title,
    description: page.description,
    markdown: `# ${page.title}\n\n${page.description}\n\n${rewriteLinks(raw).trim()}\n`,
    source: `${GH}/blob/main/${page.src}`,
  });
}

for (const [name, s] of Object.entries(sections)) {
  const [intro, ...rest] = blocks(docs[s.page]);
  const keep = s.only ? rest.filter((b) => s.only.includes(title(b))) : rest;
  if (s.only && keep.length !== s.only.length) throw new Error(`docs/${s.page}: section "${name}" expects ${s.only.join(", ")}`);
  writeFileSync(join(root, "src/content-md", `${name}.md`), render([s.only ? "" : intro, ...keep].join(""), { single: s.only?.length === 1 }));
}

// The numbers, as data. Every table in METRICS.md under its nearest H2.
for (const block of blocks(docs.metrics).slice(1)) {
  for (const t of block.match(TABLE) ?? []) {
    const [head, , ...body] = t.trim().split("\n");
    knowledge.metrics.tables.push({ title: title(block), columns: cells(head).map(plain), rows: body.map((l) => cells(l).map(plain)) });
  }
}
// A row by its label, searched across every table under headings that start with `table`.
const row = (table, label) => {
  const r = knowledge.metrics.tables.filter((t) => t.title.startsWith(table)).flatMap((t) => t.rows).find((r) => r[0] === label);
  if (!r) throw new Error(`docs/METRICS.md has no "${label}" row under "${table}"; the page needs it.`);
  return r;
};
// A cell's first clause holds its figure: "51–52 MB (peak 61 MB)" is 51 to 52, and the parenthesis is a note. The page
// draws ranges as ranges and says "about" for any ratio it makes from one.
const clause = (s) => s.split(/\(|;|,\s+[A-Za-z]/)[0];
const range = (s) => {
  const n = (clause(s).match(/\d[\d,]*(?:\.\d+)?/g) ?? ["0"]).map((v) => Number(v.replace(/,/g, "")));
  return [Math.min(...n), Math.max(...n)];
};
const note = (s) => s.match(/\(([^)]*)\)/)?.[1] ?? null;
const short = (s) => s.split(/\s*\(/)[0];
const pair = (table, label) => {
  const [, ours, theirs, ratio] = row(table, label);
  return {
    ours: short(ours),
    theirs: short(theirs),
    oursRange: range(ours),
    theirsRange: range(theirs),
    oursNote: note(ours),
    theirsNote: note(theirs),
    ratio,
  };
};
const permissions = row("What each asks", "Privacy permissions");
knowledge.facts = {
  size: pair("Footprint", "Installed size"),
  files: pair("Footprint", "Files on disk"),
  executable: pair("Footprint", "Main executable"),
  memory: pair("Runtime", "Memory footprint, idle"),
  launchPeak: pair("Runtime", "Peak memory while launching"),
  popover: row("Runtime", "Memory footprint, popover open")[1],
  cpu: pair("Runtime", "CPU, idle"),
  energy: pair("Runtime", "Energy impact, idle (top POWER)"),
  wakeups: pair("Runtime", "Idle wakeups per minute"),
  launch: pair("Runtime", "Launch to its first window existing"),
  readAll: row("Runtime", "All displays read")[1],
  confirm: row("Runtime", "Slider to confirmed level")[1],
  polls: { ours: row("Background", "Polls displays while idle")[1], theirs: row("Background", "Polls displays while idle")[2] },
  permissions: { ours: permissions[1], theirs: permissions[2].split(/,\s*/) },
  latency: { ours: row("Latency", "This app over the cable")[1], theirs: row("Latency", "DDPM over its USB bridge")[1] },
};

const f = knowledge.facts;
// The head-to-head. A row the document says was not measured is labelled so, never left blank or guessed, and the two
// rows where Dell's app does as well or better carry the document's own words for it.
const NOT = "not measured";
for (const phrase of ["about the same", "DDPM is lighter"]) {
  if (!docs.metrics.includes(phrase)) throw new Error(`docs/METRICS.md no longer says "${phrase}"; the head-to-head notes rely on it.`);
}
const asks = (label) => row("What each asks", label);
knowledge.compare = [
  ["Installed size", f.size.ours, f.size.theirs],
  ["Files on disk", f.files.ours, f.files.theirs],
  ["Memory, idle", f.memory.ours, f.memory.theirs],
  ["CPU, idle", f.cpu.ours, f.cpu.theirs],
  ["Idle wakeups per minute", f.wakeups.ours, f.wakeups.theirs],
  ["Energy impact, idle", f.energy.ours, f.energy.theirs, "top POWER column"],
  ["Polls your monitors in the background", f.polls.ours, f.polls.theirs],
  ["Launch to its first window", f.launch.ours, f.launch.theirs, "about the same"],
  ["Peak memory while launching", f.launchPeak.ours, f.launchPeak.theirs, "Dell's app is lighter here"],
  ["Privacy permissions", f.permissions.ours, `${f.permissions.theirs.length}: ${f.permissions.theirs.join(", ")}`],
  ["Network", asks("Network")[1], asks("Network")[2]],
  ["What it can change", asks("What it can change on a monitor")[1], asks("What it can change on a monitor")[2]],
].map(([label, ours, theirs, note]) => ({ label, ours, theirs, note: note ?? null, measured: theirs !== NOT }));

knowledge.release = release;
knowledge.site = {
  name: "Dell Monitor Console",
  origin: ORIGIN,
  base: `${BASE}/`,
  repo: GH,
  requires: "macOS 26 or later, Apple silicon",
  status: released
    ? `Version ${version}. Download the DMG, install with Homebrew, or build it from source.`
    : "Not released yet. There is no DMG, no Homebrew cask and no GitHub release; build it from source.",
  summary:
    `A macOS 26+ menu bar app that sets the brightness of the displays attached to your Mac, and nothing else: one popover, one slider per display, the built-in one included. ` +
    `Real backlight control over DDC/CI where a display answers, software dimming where it does not. ` +
    `${f.size.ours} installed (Dell's own app: ${f.size.theirs}), ${f.memory.ours} of memory when idle (${f.memory.theirs}), no network, no permissions, no telemetry, and it never polls your monitors. ` +
    `A lite app for the one task people open Dell's app for, not a replacement for everything. Made by Ashwin Gopalsamy. ` +
    `${released ? `Version ${version}: download the DMG, install with Homebrew, or build from source.` : "Not released yet: build from source."} Not affiliated with, endorsed by or supported by Dell.`,
  ledes,
};

// An entry may carry a second answer, "a_released", used once release.json names a version.
knowledge.faq = JSON.parse(readFileSync(join(repo, "docs/faq.json"), "utf8")).map(({ a_released, ...entry }) => ({
  ...entry,
  a: released && a_released ? a_released : entry.a,
}));
const source = [`git clone ${GH}`, "cd dell-monitor-console", "scripts/bundle.sh", 'open "build/Dell Monitor Console.app"'];
const cli = ['BIN="build/Dell Monitor Console.app/Contents/MacOS/DellMonitorConsole"', '"$BIN" --list', '"$BIN" --set U2723QE 60'];
knowledge.install = release
  ? {
      homebrew: [release.brew],
      dmg: [
        `Download ${release.dmgName} from ${release.url}`,
        "shasum -a 256 -c Dell-Monitor-Console-*.dmg.sha256",
        "gh attestation verify Dell-Monitor-Console-*.dmg -R ashwingopalsamy/dell-monitor-console",
        'Drag Dell Monitor Console.app to Applications. It is not notarised: right-click, Open, the first time, or xattr -dr com.apple.quarantine "/Applications/Dell Monitor Console.app"',
      ],
      source,
      cli,
    }
  : { source, cli };
knowledge.privacy = {
  network: "none: no URL and no socket in the sources, enforced by scripts/check-no-network.sh",
  permissions: "none: no usage descriptions, no entitlements",
  telemetry: false,
  analytics: false,
  updater: false,
  dependencies: 0,
  stores: "UserDefaults apps.ashwingopalsamy.dellmonitorconsole: the display used last, and the level of each software-dimmed display",
  sends: "one DDC/CI feature, brightness (VCP 0x10), to the displays; no power, input, preset or vendor commands",
};

writeFileSync(join(root, "src/generated/knowledge.json"), JSON.stringify(knowledge, null, 2));
console.log(`sync: ${Object.keys(sections).length} sections, ${knowledge.metrics.tables.length} tables, ${knowledge.faq.length} faq entries`);
