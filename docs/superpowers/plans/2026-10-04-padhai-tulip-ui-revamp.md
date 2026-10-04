# Padhai TULIP Vault UI & Dopamine Revamp Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform `padhai.altrusian.com` into a world-class, blissful, dopamine-inducing CBT practice web app using the Nilam 2.0 TULIP vault palette (`nilam.tulip.css`), harmonic spring micro-interactions, streak mechanics, and a clean Day/Night mode switch.

**Architecture:** Client-side TypeScript web application built with Vite, Nilam 2.0 TULIP tokens, KaTeX formula rendering, Web Crypto API AES-256-GCM chunk decryption, and Cloudflare Workers edge deployment with static asset caching.

**Tech Stack:** TypeScript, Vite, Nilam 2.0 (`nilam.css`, `nilam.tulip.css`, `nilam.motion.css`), KaTeX, Web Crypto API, Cloudflare Workers / Wrangler.

---

### Task 1: Styling Foundation & TULIP Vault Theme

**Files:**
- Modify: `web/src/styles/app.css`
- Modify: `web/index.html`

- [ ] **Step 1: Update `web/src/styles/app.css` to import TULIP and motion stylesheets**
  Import `nilam/nilam.css`, `nilam/nilam.tulip.css`, `nilam/nilam.motion.css`, and `katex/dist/katex.min.css`.
  Set root selector `:root, html` with `.tulip`, `[data-theme="tulip"]`, and `.tl-color`.
  Define glassmorphic surface tokens, harmonic spring transitions (`--spring-snap`, `--spring-settle`), glowing selection halos, dopamine badges, streak counters, and clean Day/Night variables.

- [ ] **Step 2: Update `web/index.html` with clean semantic shell**
  Replace index.html with clean semantic header:
  - Brandmark: geometric wisteria blossom SVG + "Padhai".
  - Center: breadcrumbs & streak badge mount point.
  - Right: clean Day/Night icon toggle (sun/moon), remove any "Nilam 2.0" framework badges.

- [ ] **Step 3: Test build of stylesheet**
  Run: `cd web && npx vite build --emptyOutDir false`
  Expected: Success without CSS syntax or token resolution errors.

- [ ] **Step 4: Commit Task 1**
  ```bash
  git add web/src/styles/app.css web/index.html
  git commit -m "feat(web): integrate Nilam TULIP vault tokens and clean semantic header"
  ```

---

### Task 2: Secret Vault Easter Egg & Wisteria Blossom Effects

**Files:**
- Create: `web/src/effects/blossom.ts`
- Modify: `web/src/main.ts`

- [ ] **Step 1: Create `web/src/effects/blossom.ts`**
  Implement lightweight canvas-based particle celebration effect that spawns subtle wisteria blossom petals and golden sparks when triggered (used for secret unlock and test milestones).

- [ ] **Step 2: Update `web/src/main.ts` with `listenTulipUnlock()` and Day/Night toggle**
  Import `listenTulipUnlock` and `unlockTulip` from `nilam/src/tulip.mjs` (or inline the sequence listener with identical signature).
  Hook up Day/Night mode toggle with `localStorage` persistence and `classList` toggle on `document.documentElement`.
  Listen for `nilam:tulip:unlocked` to trigger the blossom particle burst.

- [ ] **Step 3: Verify build**
  Run: `cd web && npm run build`
  Expected: Successful compilation.

- [ ] **Step 4: Commit Task 2**
  ```bash
  git add web/src/effects/blossom.ts web/src/main.ts
  git commit -m "feat(web): add wisteria blossom particle engine and secret tulip unlock listener"
  ```

---

### Task 3: Gamified Streak & Dopamine State Engine

**Files:**
- Modify: `web/src/state/quizState.ts`

- [ ] **Step 1: Enhance `quizState.ts` with streak and momentum metrics**
  Track `currentStreak`, `bestStreak`, `questionsAnsweredToday`, and dispatch streak milestone events when students answer consecutive questions.

- [ ] **Step 2: Test state transitions**
  Verify state updates correctly when answering, unanswering, and clearing responses.

- [ ] **Step 3: Commit Task 3**
  ```bash
  git add web/src/state/quizState.ts
  git commit -m "feat(web): add streak tracking and momentum events to quiz state"
  ```

---

### Task 4: High-End Question Card & Tactile Micro-Interactions

**Files:**
- Modify: `web/src/components/QuestionCard.ts`

- [ ] **Step 1: Overhaul `QuestionCard.ts` with TULIP aesthetics**
  Render frosted glass card with glowing borders (`var(--tulip-bloom-4)`).
  Apply tactile spring transitions on option buttons:
  - Spring bounce on click/key-press with `--spring-snap`.
  - Radiant wisteria halo and buttercup indicator dot on selected option.
  - High-res diagram viewer with zoom-on-click modal.
  - KaTeX mathematical rendering with clean line-height and typography.

- [ ] **Step 2: Verify build**
  Run: `cd web && npm run build`
  Expected: Clean build.

- [ ] **Step 3: Commit Task 4**
  ```bash
  git add web/src/components/QuestionCard.ts
  git commit -m "feat(web): revamp QuestionCard with tactile spring options and glassmorphism"
  ```

---

### Task 5: CBT Palette Grid & Exam View Flow

**Files:**
- Modify: `web/src/components/PaletteGrid.ts`
- Modify: `web/src/views/ExamView.ts`

- [ ] **Step 1: Redesign `PaletteGrid.ts`**
  Modern floating/docked glass matrix with real-time status pill counts:
  - Answered (glowing emerald)
  - Marked for Review (radiant wisteria violet + buttercup star)
  - Current Active (pulsing high-contrast white ring)
  - Not Visited (muted slate-teal outline)

- [ ] **Step 2: Redesign `ExamView.ts`**
  Top bar: Subject section tabs with wisteria underline indicator, live countdown timer in slate-teal pill, and live streak badge (`🔥 X Streak`).
  Bottom action bar: Previous (`P`), Next (`N`), Mark for Review (`M`), and Save & Next (`Enter`).
  Test submission modal with detailed score breakdown, accuracy rate, and celebration confetti.

- [ ] **Step 3: Verify build**
  Run: `cd web && npm run build`
  Expected: Clean build.

- [ ] **Step 4: Commit Task 5**
  ```bash
  git add web/src/components/PaletteGrid.ts web/src/views/ExamView.ts
  git commit -m "feat(web): overhaul CBT layout with floating palette and rhythm keyboard controls"
  ```

---

### Task 6: Modern Lobby & Exam Selection Dashboard

**Files:**
- Modify: `web/src/views/LobbyView.ts`

- [ ] **Step 1: Redesign `LobbyView.ts`**
  Hero header: "Master NEET & JEE With Blissful Focus" with subtle wisteria glow aura.
  Exam toggle pill: NEET (Physics, Chemistry, Biology) vs JEE (Physics, Chemistry, Mathematics).
  High-aesthetic subject cards:
  - Subject gradient icon aura.
  - Verified question count and syllabus coverage.
  - Quick action buttons: "Practice Mode" and "Timed CBT Simulation".

- [ ] **Step 2: Verify build**
  Run: `cd web && npm run build`
  Expected: Clean build.

- [ ] **Step 3: Commit Task 6**
  ```bash
  git add web/src/views/LobbyView.ts
  git commit -m "feat(web): redesign LobbyView dashboard with exam selector and subject cards"
  ```

---

### Task 7: Build, Verify & Cloudflare Edge Deployment

**Files:**
- Deployment target: `padhai.altrusian.com`

- [ ] **Step 1: Build production bundle**
  Run: `cd web && npm run build`
  Verify that `dist/index.html`, `dist/assets/*.js`, and `dist/assets/*.css` are generated cleanly.

- [ ] **Step 2: Deploy to Cloudflare Workers**
  Run: `cd web && npx wrangler deploy`
  Verify upload of assets and successful deployment to `padhai.altrusian.com`.

- [ ] **Step 3: Verify live endpoint**
  Curl `https://padhai.altrusian.com/` and verify HTTP 200, proper theme tokens, and zero console errors.

- [ ] **Step 4: Commit final release**
  ```bash
  git add -A
  git commit -m "chore(release): deploy Padhai TULIP vault UI revamp to padhai.altrusian.com"
  ```
