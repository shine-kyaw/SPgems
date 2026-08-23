# SP Gems — Website Demo

A working front-end prototype for the SP Gems website rebuild, built against
**PRD v1.0** and **SDD v1.0**.

Single-page static build: `index.html` plus `assets/img/`. No build step, no
dependencies — it runs by opening the file or serving the folder.

## What's in it

**Public site**
- Homepage (12 sections, PRD §29)
- Gemstone catalogue with faceted filtering, URL-encoded filter state (PRD §19)
- Gemstone detail page with sticky spec rail, treatment disclosure, fullscreen viewer (PRD §13)
- Our Story · The Value · Mining Works · Milestones · CSR · Responsible Sourcing
- News & Events, Contact (SDD §19.5 confirmed contact data)
- Request a Quotation + Schedule an Appointment (SDD §19.4 — no checkout)

**CMS demo** (`#/admin`)
- Dashboard with the §20.6 catalogue-hygiene widgets
- Gemstone list with saved views and bulk actions
- Gemstone editor: 10 field groups, autosave, publish-blocking validation, live preview
- Inquiries with compliance-review flagging (§21.4)
- Navigation and Site Settings globals (SDD §19.3, §19.5)
- Role switcher (§20.5) and a poor-connection simulator (§3.4, FR-CMS-040)

## Photography

All imagery is SP Gems' own, retrieved from the current live site's media
library and served locally from `assets/img/` — **not hotlinked**, per SDD §19.7,
which requires the production build to have no runtime dependency on the legacy
WordPress host.

Gemstone catalogue imagery is deliberately **schematic line-art**, not photography.
PRD §2.3 and §28.7 prohibit stock and AI-generated gemstone imagery, and the real
per-stone photography specified in §12.7 does not exist yet.

## Status

Demonstration build. The gemstone inventory, certificate numbers and inquiries are
illustrative; no data is transmitted. See the demo bar for a PRD/SDD reference overlay.
