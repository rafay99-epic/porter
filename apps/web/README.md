# Porter — Website

Marketing site for Porter, the macOS menu-bar app (`apps/desktop`). Part of the
Turborepo workspace at the repo root.

**Stack:** Turborepo · React 19 + TypeScript (strict, end-to-end typed) · Vite ·
Tailwind CSS · GSAP (ScrollTrigger + Flip). Fonts: Bricolage Grotesque (display),
Geist (text), Geist Mono — self-hosted via Fontsource.

## Concept — "Order, on arrival"

The site _performs the sort_. It opens on a scatter of real download files that
GSAP files into destination bins (the **Intake** hero), then walks one file's
journey across editorial chapters:

`Intake → Watch → Destinations → Why it works → Control → Proof → Install`

The nav is a live macOS **menu bar**; its Porter status glyph changes as you
scroll (watching → sorting → sorted), driven by `useScrollStatus`. The recreated
app windows (menu-bar panel, Dashboard, Stats, Preview, Rules, Settings) under
`src/components/appkit/` are pixel-faithful TSX rebuilds of the SwiftUI views,
scaled to any width by `ScaleToFit`.

## Workspace commands (from repo root)

```sh
npm install          # installs all workspaces
npm run dev          # turbo: vite dev server (http://localhost:5173)
npm run build        # turbo: typecheck + vite build
npm run typecheck    # turbo: tsc --noEmit across packages
```

## Layout

- `packages/core` (`@porter/core`) — **React-free**, strictly-typed domain: the
  nine categories, default rules, status metadata, install info, stats, copy.
  Mirrors the Swift source so the site never drifts from the app. The single
  source of truth.
- `apps/web/src/sections/` — the editorial chapters.
- `apps/web/src/components/appkit/` — the recreated native windows.
- `apps/web/src/components/{brand,Glyph,editorial,ScaleToFit,MenuBar}.tsx` — UI kit.
- `apps/web/src/lib/{gsap,useGsap,useScrollStatus}.ts` — motion + scroll plumbing.

## Design

Paper-and-ink editorial: warm off-white canvas, ink-black type, a single
saturated Porter blue (`#1f6ef0`), one bold dark "engineering" chapter. Mobile-
first; everything degrades under `prefers-reduced-motion`. No AI/Claude
attribution anywhere — credited to Syntax Lab Technology / Abdul Rafay.

## Install links

Primary CTA `brew install --cask rafay99-epic/tap/porter` requires a published
Homebrew tap (`rafay99-epic/homebrew-tap`) with a `porter` cask. DMG links target
the GitHub Releases assets (`Porter.dmg` / `Porter-Nightly.dmg`).
