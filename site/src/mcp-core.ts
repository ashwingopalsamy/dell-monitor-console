// The read-only tool set, shared by the browser (WebMCP) and the Worker (remote MCP).
// Pure functions over the knowledge file, so both surfaces return the same text as the page.

export interface Knowledge {
  site: { name: string; origin: string; base: string; repo: string; requires: string; status: string; summary: string };
  pages: { slug: string; url: string; anchor: string; title: string; description: string; markdown: string }[];
  faq: { id: string; q: string; a: string }[];
  metrics: { tables: { title: string; columns: string[]; rows: string[][] }[] };
  compare: { label: string; ours: string; theirs: string; note: string | null; measured: boolean }[];
  install: Record<string, string[]>;
  privacy: Record<string, unknown>;
}

export interface ToolDef {
  name: string;
  title: string;
  description: string;
  inputSchema: Record<string, unknown>;
  annotations: { readOnlyHint: true; openWorldHint: false; idempotentHint: true };
}

const annotations = { readOnlyHint: true, openWorldHint: false, idempotentHint: true } as const;
const none = { type: "object", properties: {}, additionalProperties: false };

export const TOOLS: ToolDef[] = [
  {
    name: "overview",
    title: "What it is",
    description: "What Dell Monitor Console is, what it does and does not do, its release status and where the source is.",
    inputSchema: none,
    annotations,
  },
  {
    name: "metrics",
    title: "The measurements",
    description:
      "The measured numbers against Dell's own app: size, files, memory, CPU, wakeups, launch, background activity, permissions, latency. Rows that were not measured say so.",
    inputSchema: none,
    annotations,
  },
  {
    name: "how_it_works",
    title: "How it controls a display",
    description:
      "Hardware control over DDC/CI, software dimming and the built-in path; what the row glyphs mean; why every request is sent twice and how replies are validated.",
    inputSchema: none,
    annotations,
  },
  {
    name: "install",
    title: "Install steps",
    description:
      "How to install the app (Homebrew and the DMG once a release exists; building from source always), the command-line options and how to uninstall. The status field says whether a release exists.",
    inputSchema: none,
    annotations,
  },
  {
    name: "faq",
    title: "FAQ answers",
    description: "Frequently asked questions and answers. Optionally filter by a topic word.",
    inputSchema: {
      type: "object",
      properties: { topic: { type: "string", description: "Optional word to filter on, e.g. 'permissions' or 'twice'." } },
      additionalProperties: false,
    },
    annotations,
  },
  {
    name: "privacy",
    title: "The privacy facts",
    description: "What the app contacts, asks for, stores and sends to a display, and the commands to verify each claim.",
    inputSchema: none,
    annotations,
  },
];

export function run(name: string, input: Record<string, unknown>, k: Knowledge, origin = k.site.origin): unknown {
  const home = `${origin}${k.site.base}`;
  const page = (slug: string) => {
    const p = k.pages.find((x) => x.slug === slug);
    if (!p) throw new Error(`missing page: ${slug}`);
    return { title: p.title, url: `${home}${p.anchor}`, markdown: p.markdown };
  };
  switch (name) {
    case "overview":
      return {
        name: k.site.name,
        summary: k.site.summary,
        status: k.site.status,
        requires: k.site.requires,
        source: k.site.repo,
        url: home,
        markdown: `${home}index.md`,
      };
    case "metrics":
      return { ...page("metrics"), compare: k.compare, tables: k.metrics.tables };
    case "how_it_works":
      return page("how-it-works");
    case "install":
      return { status: k.site.status, requires: k.site.requires, commands: k.install, ...page("install") };
    case "faq": {
      const topic = String(input.topic ?? "").toLowerCase().trim();
      const items = k.faq.filter((f) => !topic || `${f.q} ${f.a}`.toLowerCase().includes(topic));
      return { faq: items.map(({ q, a }) => ({ question: q, answer: a })), url: `${home}#faq` };
    }
    case "privacy":
      return { ...k.privacy, ...page("privacy") };
    default:
      throw new Error(`unknown tool: ${name}`);
  }
}
