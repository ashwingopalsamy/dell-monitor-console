import knowledge from "./generated/knowledge.json";

// Everything here is read from docs/ by scripts/sync.mjs, so the page, the mirrors and the MCP tools cannot disagree.
export const { origin: ORIGIN, base: BASE, repo: REPO, name: NAME, requires, status } = knowledge.site;

export const faq = knowledge.faq as { id: string; q: string; a: string }[];
// null until site/release.json names a version; then the DMG, its URL and the Homebrew command.
export const release = knowledge.release as {
  version: string;
  brew: string;
  dmgName: string;
  dmgUrl: string;
  url: string;
} | null;
export const facts = knowledge.facts;
export const compare = knowledge.compare as { label: string; ours: string; theirs: string; note: string | null; measured: boolean }[];
export const install = knowledge.install;
export const lede = knowledge.site.ledes as Record<string, string>;
export const pageDescription = (slug: string) => knowledge.pages.find((p) => p.slug === slug)?.description ?? "";

export const absolute = (path = "") => `${ORIGIN}${BASE}${path}`;

// A range or a figure with its unit must not break across lines: a word joiner around the en dash, a no-break space
// before the unit.
export const nb = (s: string) => s.replace(/–/g, "\u2060–\u2060").replace(/(\d) (MB|KB|ms|s|%)/g, "$1\u00a0$2");

// ---- The comparison, as the page draws it ------------------------------------------------------------------------
// Everything below is computed from facts, which sync.mjs reads out of docs/METRICS.md. Lower is better for every bar.
// A ratio made from a single figure is stated plainly; one made from a range is "about", and a range stays a range.
export const US_NAME = NAME;
export const THEM_NAME = "Dell's app (DDPM 2.3)";

type Range = [number, number];
const mid = (r: Range) => (r[0] + r[1]) / 2;
// 47, 1.8, 2.5: whole numbers from ten up, one decimal below.
const times = (n: number) => `${n >= 10 ? Math.round(n) : Math.round(n * 10) / 10}×`;
const ordinal = (n: number) => `${n}${n % 100 >= 11 && n % 100 <= 13 ? "th" : (["th", "st", "nd", "rd"][n % 10] ?? "th")}`;
const oneIn = (n: number) => `1/${ordinal(Math.round(n))}`;
const grow = (value: number, max: number) => Math.min(1, value / max);

export interface Meter {
  value: string;
  // How much of the track the bar fills, 0 to 1, drawn to scale against the longer bar of its card.
  share: number;
  // What a very short bar is, in words: "1/47th".
  tag?: string;
  zero?: boolean;
  // The mark on the better bar: text, so colour is never the only signal.
  mark?: { text: string; kind: "win" | "them" | "tie" };
}
export interface Card {
  id: string;
  metric: string;
  verdict: string;
  kind: "win" | "tie" | "lose";
  ours: Meter;
  theirs: Meter;
  caption?: string;
}

type Pair = { ours: string; theirs: string; oursRange: Range; theirsRange: Range; oursNote: string | null; theirsNote: string | null; ratio?: string };

// A card where ours is the lower figure. A zero reads as "none", drawn as an empty ring, never as a sliver.
function win(id: string, metric: string, p: Pair, verdict: string, markText: string, caption?: string, tag?: string): Card {
  const zero = p.oursRange[1] === 0;
  const max = Math.max(mid(p.oursRange), mid(p.theirsRange));
  return {
    id,
    metric,
    verdict,
    kind: "win",
    ours: {
      value: p.ours,
      share: zero ? 0 : grow(mid(p.oursRange), max),
      zero,
      tag: zero ? "none" : tag,
      mark: { text: markText, kind: "win" },
    },
    theirs: { value: p.theirs, share: grow(mid(p.theirsRange), max) },
    caption,
  };
}
const gap = (p: Pair) => mid(p.theirsRange) / mid(p.oursRange);

const f = facts as unknown as Record<string, Pair> & {
  permissions: { ours: string; theirs: string[] };
  popover: string;
};
const fewerPermissions = f.permissions.theirs.length - (f.permissions.ours === "none" ? 0 : f.permissions.theirs.length);

// In order of how much each matters to someone who only wants to set a brightness.
export const wins: Card[] = [
  win("size", "Installed size", f.size, f.size.ratio ?? "", "Smaller", `Main executable: ${f.executable.ours} against ${f.executable.theirs}.`, oneIn(gap(f.size))),
  win(
    "memory",
    "Memory, idle",
    f.memory,
    `About ${times(gap(f.memory))} less memory`,
    "Less",
    `Freshly launched, then left alone.${f.memory.theirsNote ? ` Dell's app: ${f.memory.theirs} (${f.memory.theirsNote}).` : ""}`,
  ),
  win("cpu", "CPU, idle", f.cpu, f.cpu.oursRange[1] === 0 ? "No idle CPU" : `About ${times(gap(f.cpu))} less CPU`, "Less", "Sampled with top while idle."),
  win(
    "wakeups",
    "Wakeups per minute, idle",
    f.wakeups,
    `About ${Math.round(f.wakeups.theirsRange[0] / mid(f.wakeups.oursRange))}–${Math.round(f.wakeups.theirsRange[1] / mid(f.wakeups.oursRange))}× fewer wakeups`,
    "Fewer",
    "How often the app wakes while nobody is using it. Ours does nothing between your adjustments.",
    `${oneIn(f.wakeups.theirsRange[0] / mid(f.wakeups.oursRange))}–${oneIn(f.wakeups.theirsRange[1] / mid(f.wakeups.oursRange))}`,
  ),
  win(
    "energy",
    "Energy impact, idle",
    f.energy,
    f.energy.oursRange[1] === 0 ? "No idle energy impact" : `About ${times(gap(f.energy))} less energy`,
    "Less",
    "top's POWER column: an instant reading, not battery life.",
  ),
  {
    id: "permissions",
    metric: "Privacy permissions",
    verdict: `${fewerPermissions} permissions fewer`,
    kind: "win",
    ours: { value: f.permissions.ours === "none" ? "0" : f.permissions.ours, share: 0, mark: { text: "Fewer", kind: "win" } },
    theirs: { value: String(f.permissions.theirs.length), share: 1 },
    caption: "Ours declares no usage descriptions and no entitlements.",
  },
  win("files", "Files on disk", f.files, `${f.files.ratio} files`, "Fewer", undefined, oneIn(gap(f.files))),
];

export const losses: Card[] = [
  {
    id: "peak",
    metric: "Peak memory while launching",
    verdict: `Dell's app is about ${times(mid(f.launchPeak.oursRange) / mid(f.launchPeak.theirsRange))} lighter here`,
    kind: "lose",
    ours: { value: f.launchPeak.ours, share: 1 },
    theirs: {
      value: f.launchPeak.theirs,
      share: grow(mid(f.launchPeak.theirsRange), mid(f.launchPeak.oursRange)),
      mark: { text: "Dell's app is lighter here", kind: "them" },
    },
    caption: `Ours spikes for a moment (${f.launchPeak.oursNote ?? "warm-up"}), then settles to ${f.memory.ours}.`,
  },
  {
    id: "launch",
    metric: "Launch to its first window",
    verdict: "About the same",
    kind: "tie",
    ours: { value: f.launch.ours, share: 1, mark: { text: "Same", kind: "tie" } },
    theirs: { value: f.launch.theirs, share: 1, mark: { text: "Same", kind: "tie" } },
    caption: `Bars drawn equal. Runs: ours ${f.launch.oursNote}; Dell's app ${f.launch.theirsNote}, and its window starts hidden.`,
  },
];

// The hero's four tiles: our figure, then Dell's, with the margin as a pill and one thin comparison bar.
export interface Tile {
  label: string;
  ours: string;
  theirs: string;
  share: number;
  pill: string;
}
export const tiles: Tile[] = [
  { label: "Installed size", ours: f.size.ours, theirs: f.size.theirs, share: grow(mid(f.size.oursRange), mid(f.size.theirsRange)), pill: f.size.ratio ?? "" },
  { label: "Memory, idle", ours: f.memory.ours, theirs: f.memory.theirs, share: grow(mid(f.memory.oursRange), mid(f.memory.theirsRange)), pill: `about ${times(gap(f.memory))} less` },
  {
    label: "CPU, idle",
    ours: f.cpu.ours,
    theirs: f.cpu.theirs,
    share: grow(mid(f.cpu.oursRange), mid(f.cpu.theirsRange)),
    pill: f.cpu.oursRange[1] === 0 ? "none at all" : `about ${times(gap(f.cpu))} less`,
  },
  {
    label: "Privacy permissions",
    ours: f.permissions.ours === "none" ? "0" : f.permissions.ours,
    theirs: String(f.permissions.theirs.length),
    share: 0,
    pill: `${fewerPermissions} fewer`,
  },
];

// One sentence for search results and share cards. The numbers come from docs/METRICS.md.
export const description = `A lite macOS menu bar app for the brightness of your Dell and other DDC/CI displays. One slider each, ${facts.size.ours} installed, no network, no permissions.`;

const author = {
  "@type": "Person",
  "@id": "https://ashwingopalsamy.in/#person",
  name: "Ashwin Gopalsamy",
  url: "https://ashwingopalsamy.in",
};

// No licence or price, and a version and download URL only once release.json names one: structured data should not
// invent them.
export function softwareApplication() {
  return {
    "@type": "SoftwareApplication",
    "@id": `${absolute()}#app`,
    name: NAME,
    description: knowledge.site.summary,
    url: absolute(),
    applicationCategory: "UtilitiesApplication",
    operatingSystem: "macOS 26 or later",
    installUrl: absolute("#install"),
    ...(release && { softwareVersion: release.version, downloadUrl: release.dmgUrl }),
    softwareRequirements: requires,
    keywords: ["Dell", "monitor brightness", "DDC/CI", "menu bar app", "macOS", "Apple silicon", "software dimming", "VCP 0x10"],
    featureList: [
      "One brightness slider per display, the built-in one included",
      "Real backlight control over DDC/CI where a display answers, software dimming where it does not",
      "Scroll over the menu bar icon to nudge the display used last",
      "Every reply validated and every level read back before it is shown as set",
      "No network, no permissions, no telemetry, no updater",
    ],
    author,
    publisher: author,
    sameAs: [REPO],
  };
}

export function webSite() {
  return { "@type": "WebSite", "@id": `${absolute()}#site`, name: NAME, url: absolute(), inLanguage: "en", publisher: author };
}

export function sourceCode() {
  return {
    "@type": "SoftwareSourceCode",
    name: `${NAME} source`,
    codeRepository: REPO,
    programmingLanguage: "Swift",
    runtimePlatform: "macOS",
    author,
  };
}

export function faqPage(entries = faq) {
  return {
    "@type": "FAQPage",
    mainEntity: entries.map((e) => ({ "@type": "Question", name: e.q, acceptedAnswer: { "@type": "Answer", text: e.a } })),
  };
}

export function howToInstall() {
  const steps = release
    ? [
        `Install with Homebrew: ${release.brew}, or download ${release.dmgName} from the latest release and drag the app to Applications.`,
        "Open Dell Monitor Console. It is not notarised, so macOS asks once: right-click the app and choose Open.",
      ]
    : [
        `Clone the repository: ${install.source[0]}, then cd dell-monitor-console.`,
        "Build and sign the app with scripts/bundle.sh. There are no dependencies to fetch.",
        "Open build/Dell Monitor Console.app. It is ad hoc signed, so macOS asks once: right-click the app and choose Open.",
      ];
  return {
    "@type": "HowTo",
    name: release ? "Install Dell Monitor Console" : "Build and open Dell Monitor Console",
    ...(!release && { tool: [{ "@type": "HowToTool", name: "Xcode 26 or its Command Line Tools" }] }),
    step: steps.map((text, i) => ({ "@type": "HowToStep", position: i + 1, text })),
  };
}

export const graph = (...nodes: object[]) => ({ "@context": "https://schema.org", "@graph": nodes });
