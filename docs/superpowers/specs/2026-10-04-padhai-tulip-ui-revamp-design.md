# Padhai Web App: TULIP Vault Aesthetic & UX Revamp Design

- **Date:** 2026-10-04
- **Product:** Padhai (`padhai.altrusian.com`)
- **Status:** Approved
- **Palette:** Nilam 2.0 TULIP Vault (`nilam.tulip.css` / `src/tulip.mjs`)

---

## 1. Executive Summary

Padhai is the high-performance desktop and mobile web client for QuestionX, serving 18,642 NEET and JEE questions with client-side AES-256-GCM authenticated decryption, KaTeX formula typesetting, and high-resolution diagrams.

This design document outlines the end-to-end aesthetic, psychological, and engineering overhaul of Padhai to deliver a delightful, dopamine-inducing study experience for students, adopting the newly released **TULIP Vault** palette from Nilam 2.0 (`commit c0b4272`), inspired by Japanese wisteria flower art.

---

## 2. Core Brand Identity & Palette Contract

### 2.1 The TULIP Palette Roles

All exposed design framework badges (e.g. "Nilam 2.0") and custom theme pickers are eliminated in favor of a locked, signature identity with a streamlined Day / Night mode toggle.

| Palette Role | Solved OKLCH Coordinate | Visual & Semantic Assignment |
| :--- | :--- | :--- |
| **Bloom (Brand Primary)** | OKLCH `h: 292`, `L: 0.66` (Wisteria Glow) | Brand mark, primary action buttons, active tab borders, option selection halos, and focus rings. |
| **Buttercup (Reward & Highlight)** | OKLCH `h: 98`, `L: 0.66` (Canary Yellow) | Answer streaks (`🔥 15 Streak`), XP/momentum counters, review bookmark stars, warning states, and celebration confetti. |
| **Stem (Navigation & Structure)** | OKLCH `h: 252`, `L: 0.66` (Slate-Teal Vine) | Metadata chips, exam/subject tags, timer pill, question numbers, and inactive CBT grid borders. |
| **Plum (Depth & Calyx Shadows)** | OKLCH `h: 310`, `L: 0.66` (Orchid Shadow) | Midnight surface gradients, elevated card backdrops, modal scrims, and deep contrast borders. |

### 2.2 Color Modes (Light & Dark)

- **Dark Mode (Default):**
  - Base canvas: `oklch(0.12 0.007 292.0)` (Deep obsidian with subtle wisteria violet tint).
  - Cards & Panels: Frosted glassmorphism `rgba(24, 20, 42, 0.7)` with `backdrop-filter: blur(16px)` and subtle `1px` translucent wisteria border (`var(--tulip-bloom-4)`).
  - Text: High contrast white/silver reading text (`oklch(0.96 0.005 292.0)`).
- **Light Mode:**
  - Base canvas: `oklch(0.985 0.004 292.0)` (Crisp porcelain white with wisteria warmth).
  - Cards & Panels: Pure white `rgba(255, 255, 255, 0.9)` with soft diffuse shadows (`0 8px 30px rgba(99, 50, 150, 0.06)`).
  - Text: High contrast deep plum (`oklch(0.18 0.008 310.0)`).

### 2.3 Secret Vault Rail (`listenTulipUnlock`)

The secret activation sequence `'t'` $\to$ `'u'` $\to$ `'l'` $\to$ `'i'` $\to$ `'p'` will remain active via `listenTulipUnlock()`. When triggered, it broadcasts `nilam:tulip:unlocked` and triggers an animated wisteria floral particle burst across the screen with a subtle celebratory audio haptic.

---

## 3. Psychological & Dopamine Architecture

1. **Tactile Spring Micro-Interactions:**
   - Incorporate Nilam's Apple-calibrated harmonic spring tokens:
     - `--spring-snap: linear(0, 0.007 2%, ..., 1)` (`240ms` with 2.4% overshoot) for button clicks and option selections.
     - `--spring-settle` (`300ms`) for card entries, modal popovers, and question changes.
   - When an option is clicked or triggered via keyboard (`1-4`), the card compresses subtly (`scale(0.985)`), expands with a soft wisteria glow halo, and reveals a vibrant checkmark.

2. **Momentum & Streak Engine:**
   - Header features a live momentum tracker: `🔥 12 Streak`.
   - Reaching milestones (5, 10, 25 in a row) triggers a celebratory buttercup bloom shimmer with a brief micro-badge pulse.

3. **CBT Practice Matrix (Stress-Free & Informative):**
   - 200-question matrix for NEET and JEE full tests.
   - Status indicators:
     - *Answered:* Glowing emerald green badge (`var(--ok-9)` with `var(--ok-ink)`).
     - *Marked for Review:* Radiant wisteria violet with small buttercup star (`var(--tulip-bloom-9)` + `var(--tulip-buttercup-9)`).
     - *Current Active:* Pulsing high-contrast white ring with slate-teal glow.
     - *Not Visited:* Muted translucent slate-teal capsule.

4. **Keyboard-Driven CBT Rhythm:**
   - Single-key shortcuts: `1`, `2`, `3`, `4` (or `A`, `B`, `C`, `D`) for options.
   - `N` for Next, `P` for Previous, `M` for Mark for Review, `Enter` to Save & Next.
   - Transition between questions executes in 150ms with zero jank.

---

## 4. Architectural & File Breakdown

### 4.1 `web/src/styles/app.css`
- Import:
  - `nilam/nilam.css`
  - `nilam/nilam.tulip.css`
  - `nilam/nilam.motion.css`
  - `katex/dist/katex.min.css`
- Apply `.tulip`, `[data-theme="tulip"]`, and `.tl-color` tokens to `:root` / `html`.
- Define glassmorphic surface tokens, harmonic spring utility classes, KaTeX math typesetting enhancements, and responsive layout grids.

### 4.2 `web/index.html`
- Clean, minimal HTML5 document shell.
- Semantic header:
  - Left: Padhai brandmark (geometric wisteria blossom SVG) + "Padhai" in 700-weight typography.
  - Center: Active subject/exam breadcrumbs and real-time streak meter.
  - Right: Minimal Day/Night mode button (Sun/Moon glyph) and full-screen toggle.
- Mount point `<div id="app"></div>`.

### 4.3 `web/src/main.ts`
- Root controller initializing state, theme preference (`localStorage`), and event listeners.
- Invokes `listenTulipUnlock()` from `nilam` to maintain secret easter egg accessibility.
- Orchestrates view rendering (`LobbyView` vs `ExamView`).

### 4.4 `web/src/views/LobbyView.ts`
- Hero greeting with encouraging study copy.
- Exam selection toggle: **NEET** (Physics, Chemistry, Biology) vs **JEE Main / Adv** (Physics, Chemistry, Mathematics).
- High-aesthetic subject cards featuring:
  - Subject icon with wisteria/buttercup gradient aura.
  - Question count and verified status badge.
  - Direct "Start Practice" and "Timed Mock CBT" triggers.

### 4.5 `web/src/views/ExamView.ts`
- Split-screen CBT layout:
  - Left Panel: Question stem, responsive KaTeX math rendering, zoomable high-res diagrams, and spring-animated option rows.
  - Right Panel: Real-time countdown timer, question palette grid, section switcher, and test submission controls.
- Instant solution modal with detailed step-by-step reasoning upon submitting a question in practice mode.

### 4.6 `web/src/components/QuestionCard.ts`
- Render question stem and sanitize LaTeX strings for KaTeX.
- Responsive diagram container supporting SVG and JPG/PNG with click-to-expand lightbox.
- Damped-harmonic option selection animations.

---

## 5. Verification & Quality Gates

1. **TypeScript & Build Verification:**
   - `npm run build` in `web/` must compile with 0 TypeScript errors and produce optimized static assets in `web/dist/`.
2. **Contrast & Accessibility (WCAG 2.1 AA/AAA):**
   - Light mode text contrast $\ge 7:1$ (Deep plum `#1e142e` against `#fcfbfe`).
   - Dark mode text contrast $\ge 9:1$ (Silver/white `#f7f5fd` against `#0e0d17`).
   - Deuteranope/colorblind-safe status tokens.
3. **Deployment Verification:**
   - Execute `npx wrangler deploy` to push the revamped static bundle and worker to `padhai.altrusian.com`.
   - Verify live endpoint returns HTTP 200 with refreshed design tokens and responsive layout.
