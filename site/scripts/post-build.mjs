// The machine layer: Markdown mirrors, sitemap, llms files, feed and the knowledge file, written into dist/.
// Everything is derived from src/generated/knowledge.json, so a page and its mirror cannot disagree.
import { readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const dist = join(root, "dist");
const knowledge = JSON.parse(readFileSync(join(root, "src/generated/knowledge.json"), "utf8"));
const { site } = knowledge;
const abs = (path = "") => `${site.origin}${site.base}${path}`;
const today = new Date().toISOString().slice(0, 10);

const write = (name, text) => {
  const file = join(dist, name);
  mkdirSync(dirname(file), { recursive: true });
  writeFileSync(file, text);
};
const absolutise = (md) => md.replaceAll(`](${site.base}`, `](${site.origin}${site.base}`);
const xml = (s) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");

// Markdown mirrors: /<slug>.md next to the page.
// knowledge.json keeps each page as "# title, description, body"; a mirror leads with its own header instead.
const bodyOf = (p) => p.markdown.slice(`# ${p.title}\n\n${p.description}\n\n`.length);
const mirrors = knowledge.pages.map((p) => ({
  ...p,
  text: `# ${p.title}\n\n> ${p.description}\n\nCanonical: ${abs(p.anchor)}\n\n${absolutise(bodyOf(p)).trim()}\n`,
}));
for (const m of mirrors) write(`${m.slug}.md`, m.text);

const faqText = knowledge.faq.map((f) => `## ${f.q}\n\n${f.a}\n`).join("\n");
write("faq.md", `# FAQ\n\n> Short answers about ${site.name}.\n\nCanonical: ${abs("#faq")}\n\n${faqText}`);

const bySlug = Object.fromEntries(mirrors.map((m) => [m.slug, m]));
const homeLinks =
  "## Start here\n" +
  ["install", "how-it-works", "privacy", "metrics"]
    .map((s) => `- [${bySlug[s].title}](${abs(`${s}.md`)}): ${bySlug[s].description}`)
    .join("\n");
const optional = `## Optional\n- [FAQ](${abs("faq.md")}): short answers, also as JSON-LD on the page.\n- [Source](${site.repo}): Swift 6, no dependencies.\n${knowledge.release ? `- [Releases](${knowledge.release.url}): the DMG, its checksum and build attestation.\n` : ""}- [MCP server](${abs("mcp")}): read-only tools over these docs, streamable HTTP.\n`;
write("index.md", `# ${site.name}\n\n> ${site.summary}\n\nStatus: ${site.status}\n\nCanonical: ${abs()}\n\n${homeLinks}\n\n${optional}`);
write("llms.txt", `# ${site.name}\n\n> ${site.summary}\n\n${homeLinks}\n\n${optional}`);
write(
  "llms-full.txt",
  `# ${site.name}\n\n> ${site.summary}\n\n${mirrors.map((m) => m.text).join("\n---\n\n")}\n---\n\n# FAQ\n\n${faqText}`,
);

write(
  "sitemap.xml",
  `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n  <url><loc>${abs()}</loc><lastmod>${today}</lastmod></url>\n</urlset>\n`,
);

// Atom feed from CHANGELOG.md's versioned sections. Until the first one exists it is valid and empty, so a reader can
// subscribe now and the first entry arrives with the first release.
const changelogPath = join(root, "..", "CHANGELOG.md");
const changelog = existsSync(changelogPath) ? readFileSync(changelogPath, "utf8") : "";
const entries = [...changelog.matchAll(/^## \[(\d+\.\d+\.\d+)\] - (\d{4}-\d{2}-\d{2})\n([\s\S]*?)(?=^## \[|\s*$(?![\r\n]))/gm)].map(
  (m) => ({ version: m[1], date: m[2], notes: m[3].trim() }),
);
write(
  "feed.xml",
  `<?xml version="1.0" encoding="UTF-8"?>\n<feed xmlns="http://www.w3.org/2005/Atom">\n  <title>${site.name} releases</title>\n  <id>${abs("feed.xml")}</id>\n  <link rel="self" href="${abs("feed.xml")}"/>\n  <link href="${abs()}"/>\n  <updated>${entries[0]?.date ?? today}T00:00:00Z</updated>\n  <author><name>Ashwin Gopalsamy</name></author>\n${entries
    .map(
      (e) =>
        `  <entry>\n    <title>${xml(e.version)}</title>\n    <id>${site.repo}/releases/tag/v${e.version}</id>\n    <link href="${site.repo}/releases/tag/v${e.version}"/>\n    <updated>${e.date}T00:00:00Z</updated>\n    <content type="text">${xml(e.notes)}</content>\n  </entry>`,
    )
    .join("\n")}\n</feed>\n`,
);

write("knowledge.json", JSON.stringify(knowledge));
console.log(`post-build: ${mirrors.length + 2} markdown mirrors, 1 sitemap url, ${entries.length} feed entries`);
