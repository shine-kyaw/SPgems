# SP Gems — website demo

A design and content demo of the site specified in **SP Gems Website PRD v1.0**.

Its job is to settle the design system, the information architecture, the page templates
and the data model, so that those decisions get made against something real rather than
against a description. **[Read the demo notes →](src/demo-notes.html)** — that page is the
canonical account of what is real here and what is not, and it is published as part of the
site at `/demo-notes.html`.

## Read this first

There is **no gemstone photography** in this build, deliberately. PRD §28.7 prohibits stock
and AI-generated imagery of gemstones or jewellery outright — in a category whose premise is
authenticity, a synthetic image found by a customer would be commercially catastrophic.

Instead every image slot renders a **specimen plate**: the gemmological neutral mid-grey
ground of FR-CAT-040 (`#8A8A8A`), at the true aspect ratio the slot will use, carrying the
shot specification for that slot. Layout is honest about proportion and weight, and every
placeholder doubles as a photography brief.

The inventory is likewise **specimen data** — structurally complete, commercially fictional.
Certificate numbers use the literal placeholder pattern `GRS20XX-XXXXXX` and are deliberately
not valid report numbers. The whole site is `noindex` and `robots.txt` disallows everything.

## Stack, and why it is not the recommended one

PRD §35 recommends Next.js + Payload CMS 3 + PostgreSQL for production, and nothing here
argues against that.

This demo is static HTML, hand-written CSS and vanilla JS, assembled by a PowerShell
generator. It deploys to Vercel with no build step and no database, needs no Node toolchain,
and a demo's job — design, IA, data model, copy — is not stack-dependent. Everything
transfers: the CSS is a token file, the data is JSON matching the CMS field spec, and the JS
is framework-free and specifies the interaction contract precisely enough to reimplement as
React components without guessing.

## Layout

```
src/                  page sources — a small metadata block plus the page body
tools/partials/       shared chrome: head, header, footer, enquiry modal, viewer, filter rail
tools/templates/      gemstone and jewellery detail templates
tools/build.ps1       the generator
tools/serve.ps1       local static server for preview
data/gemstones.json   mirrors PRD §12.3 field for field
data/jewellery.json   mirrors PRD §14.2
data/articles.json    the twelve-article launch set of §17.2
assets/css/site.css   the design system — every token from §28.2, the §28.3 type scale,
                      the §28.4 spacing scale, §28.5 components, §28.6 motion
assets/css/plates.css the placeholder system — delete this file at photography hand-off
assets/css/catalogue.css  catalogue and detail templates, loaded per route
assets/js/            site.js (shared), catalogue.js (§19), gem.js (§13.8, §26A.4)
```

Generated HTML is written to the repository root and **committed**, so Vercel serves it
directly with no build step.

## Working on it

Regenerate after any change to `src/`, `data/`, `tools/partials/` or `tools/templates/`:

```bash
powershell -ExecutionPolicy Bypass -File tools/build.ps1
```

Preview locally on <http://localhost:8787>:

```bash
powershell -ExecutionPolicy Bypass -File tools/serve.ps1 -Port 8787
```

Adding a stone is a data edit plus a rebuild — the detail page, the catalogue card, the
filter counts, the related-stone scoring and the search index all follow from the JSON.

`build.ps1` and `serve.ps1` must be saved as **UTF-8 with BOM**. PowerShell 5.1 reads
BOM-less `.ps1` files as ANSI and mangles them into parse errors.

## What is implemented

- **Design system** — all §28 tokens and component rules, including the prohibitions: no
  gradients except a hero scrim, no glassmorphism, no card shadows, nothing above a 2px
  radius, no carousels for primary content, no arrival modal.
- **IA and URLs** — the six-item nav of §9.2, mega-menus of §9.3, URL structure of §10
  including the gemstone slug pattern.
- **Catalogue (§12, §19)** — faceted filtering with full URL state, live counts announced to
  screen readers, zero-count options disabled rather than hidden, removable filter chips,
  real pagination, six sort orders, and a diagnostic zero-result state that names the most
  constraining filter and offers one-click relief.
- **Gemstone detail (§13)** — two-column sticky rail, the eight-field key spec table with
  keyboard-operable glossary disclosures, price and availability per §12.5, exactly one
  primary CTA, the mandatory treatment-disclosure section on every page whether heated or
  not, certification with outbound lab verification, full gallery, related-stone scoring per
  FR-GEM-070, and permanent sold-stone records.
- **Full-screen viewer (§13.8)** — all four zoom inputs (wheel, pinch, double-tap, controls),
  drag and arrow-key panning, image navigation, focus trap, focus restoration on close.
- **Mobile (§26A)** — 56px header, full-screen nav overlay, two-column catalogue with a
  persisted single-column toggle, full-screen filter sheet with a live "Show N results"
  button, swipeable detail carousel, and the sticky bottom action bar.
- **Conversion** — contextual enquiry modal pre-populated with stone ID, title and URL;
  three-step skippable commission flow with session persistence; request-and-confirm
  consultation flow with both time zones shown explicitly (Myanmar is UTC+**06:30**); trade
  sourcing brief.
- **Search (§19.3)** — grouped results, Levenshtein typo tolerance, and exact stone-ID
  resolution straight to the record.

## What is not

No backend — forms render their confirmation state and log to the console. No CMS. No file
upload. No 360° spin, scrollytelling, interactive map, trade accounts, localisation or
analytics; all are Phase 2/3 in §37–38. Seven of the twelve articles are shown on the Learn
hub as the editorial plan rather than as empty pages, per §36.2.

## What SP Gems needs to supply

In priority order, with the detail on each: **[demo notes → what we need](src/demo-notes.html)**.
Short version: photography standard and pilot shoot; sixty stones of inventory data; company
registration details and a professional domain email; counsel review of the sourcing,
compliance and legal pages; real answers on payment, shipping and the commission process; the
"is The Value a collection or a sub-brand" decision; and a named owner for catalogue upkeep.

The last one is the one that quietly kills projects like this. The 2017 content freeze on the
current site is the evidence.
