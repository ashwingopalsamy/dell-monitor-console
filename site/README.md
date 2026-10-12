# Site

The project site, <https://apps.ashwingopalsamy.in/dell-monitor-console/>. One page for people, with the numbers,
control, privacy, install and FAQ sections on the same scroll, plus Markdown mirrors, `llms.txt` and an MCP endpoint
for search engines and agents.

```sh
cd site
npm ci
npm run dev        # sync docs, then astro dev
npm run build      # sync, build, markdown mirrors, sitemap, llms files, share card, icons
npm run deploy     # build, then wrangler deploy the app Worker
```

- **Content** comes from the repository: `docs/*.md` and `docs/faq.json`. `scripts/sync.mjs` turns them into
  `src/content-md/` (rendered into the page sections, shell blocks highlighted at build time, tables made responsive)
  and `src/generated/knowledge.json`. Every number on the page is read from `docs/METRICS.md`; a row the page needs
  that goes missing fails the build. Edit the sources, not the generated files.
- **Release switch**: `release.json` is `{"version": null}` until there is a release. While it is null the page says
  "not released yet" and offers only the build-from-source commands. Set it to `"1.0.0"` (or the real version) and the
  hero offers the DMG at `releases/download/v<version>/Dell-Monitor-Console-<version>.dmg`, a copy-able Homebrew
  command and "Other ways to install", and the Install section, FAQ, `llms.txt`, `index.md` and MCP tools follow.
  Docs mark the text that changes with `<!-- unreleased -->` and `<!-- released ... -->` blocks, and `docs/faq.json`
  entries may carry an `a_released` answer. Set the version only once the DMG and the cask exist: nothing checks.
- **The console** in the hero is `src/components/Dial.astro` and `Row.astro` plus `src/scripts/dial.ts`. The dial's
  geometry is `src/dial.ts`, copied from `AppIconRenderer.swift`; `/favicon.svg` is drawn from the same module.
- **`worker/`** serves the build, a read-only MCP endpoint at `/mcp`, Markdown for `Accept: text/markdown`, and the
  security headers. `src/mcp-core.ts` holds the six tools; the browser registers the same ones through WebMCP when
  `navigator.modelContext` exists.
- **Hub**: `hub-entry.json` is the entry the shared hub (outside this repository) needs to list and route this app.
- **Mirror**: `MIRROR=1 npm run build` produces the GitHub Pages copy. Same base path, `noindex`, canonical pointing
  at the apps URL. `.github/workflows/site.yml` does this.
- **Icons**: `public/` holds what `scripts/brand.sh` renders from the app. `scripts/icons.mjs` derives `favicon.ico`
  and the maskable PWA icon from those layers at build time.
- **No analytics, no third-party requests.** Fonts are self-hosted and the CSP says `script-src 'self'`.
