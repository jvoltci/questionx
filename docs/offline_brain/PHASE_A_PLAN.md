# `questionx-offline-brain` v0.1 — Phase A Plan

> Decision being validated: a ≤2MB on-device blob (retrieval index + tiny model) can answer NEET MCQs at ≥85% top-1 on a 500-Q held-out set. BUILD if yes, KILL if no.
>
> Source mission: `/Users/shivya/Documents/volt/idea/.claude/memory/decision_log.md` (2026-05-29 entry).
> Status: **awaiting user approval before Phase B implementation.**

---

## 0. Hypothesis (verbatim)

> A ≤2MB on-device retrieval + tiny LM combo, indexing the NEET syllabus, can answer NEET-style questions at ≥85% top-1 accuracy on a held-out set of 500 real questions.

What "answer" means in this plan: given `{question_latex, options[4]}`, the system outputs `A|B|C|D`. Top-1 accuracy = `% picked == answer_key`. We are **not** evaluating retrieval-of-similar-PYQ, which would conflate "deduping the corpus" with "knowing the syllabus."

## 1. Three base-model candidates

All three are ranked against an explicit on-device constraint: **inference must run in pure Dart or via a lightweight FFI**, because we ship a Flutter APK to ₹6000 Android devices. Heavy runtimes (`onnxruntime`, `tflite_flutter`) add 8–20MB to the APK and undermine the "2MB" promise. This rules out heavyweight transformer encoders on the device.

| | **A. TF-IDF + BM25 chunk index** | **B. Static embeddings (model2vec-style)** | **C. Distilled MiniLM-L2-128** |
|---|---|---|---|
| What | Sparse term–doc matrix over NCERT chunks; option scored by overlap with retrieved chunk. No model — pure lookup. | Distilled static vocab embedding (1 vector / token, no transformer). Lookup → mean-pool → cosine. | 2-layer transformer encoder distilled from MiniLM. Forward pass on-device. |
| Pre-quantization size | n/a (corpus only) | ~30 MB (`minishlab/M2V_base_output`) | ~10 MB fp32 |
| Post-quantization (2MB target) | Vocab pruned to ~10k syllabus terms + zstd-compressed chunks → **~1.8 MB** | 8k vocab × 256-dim int8 lookup → **~2.0 MB**, OR 16k × 128-dim int8 → **~2.0 MB** | int8 + 2-layer 128-dim + pruning → **~2.2 MB** (over budget by ~200 KB; needs int4 or further prune) |
| On-device runtime | Pure Dart, no deps | Pure Dart hashmap + vector ops | onnxruntime_flutter or tflite (adds ~12MB to APK) |
| Expected 2MB accuracy | 55–70% (informed guess from BM25-on-MCQ literature for science domains) | 65–80% (static embeddings retain ~85% of MiniLM quality at 1/10 the size on retrieval benchmarks; MCQ is harder) | 70–85% (real transformer math; but runtime cost is the killer) |
| Inference latency on low-end Android | <50ms (pure index lookup) | <100ms (vocab lookup + N × dot product) | 200–800ms (transformer forward pass) |
| Risk to 2MB ceiling | Low. Index is the only thing taking space. | Low. Vocab × dim × int8 is dialable. | **High.** Pruning to 2MB likely tanks accuracy; runtime fattens APK. |
| **Recommendation** | **Ship as the baseline floor.** If it already hits 85%, no need for B/C. | **Primary contender for the 2MB tier.** Best size/quality/runtime triangle. | **Race horse, not the workhorse.** Run for upper-bound comparison only. |

**Plan: build A first (baseline, day 2), B as the candidate to validate the hypothesis (day 3), C only for ceiling comparison (day 4).** Commit to the best 2MB candidate by end of day 4. Do not switch after.

## 2. Data prep — the 500-question held-out set

### Source

**`assets/neet.json`** (3856 audited Qs). Random stratified split, never indexed by the brain. Stratification axes: `subject × year_bucket` (pre-2015 AIPMT vs 2015+ NEET vs 2024–25).

| | Held-out (500) | Corpus / training side (3356) |
|---|---|---|
| Physics | 125 | 842 |
| Chemistry | 125 | 817 |
| Biology | 250 | 1677 |
| General Knowledge (20 total) | excluded — too few | excluded |
| Year split | 60% pre-NTA, 40% NTA-era | same |

### Why not scrape new questions from neetprep

The neetprep bulk scrape is on the deprecated list (`project_session_15_methodology.md`). The volt/idea mission spec says "use the existing neetprep pipeline; do NOT scrape new sources" — interpreting this as: rely on the **already-cleaned `neet.json`** that was produced by neetprep then audited. Not re-run the scraper.

### Why this split is honest

The brain's **index** is NCERT syllabus chunks (§3.5 below), not the question text. So holding out 500 Qs from `neet.json` doesn't leak — the brain has never seen them and never seen any question's text. The split is purely an eval-isolation guard against accidental future-leakage if we later add Q-based retrieval.

### Trust caveat

`project_audit_in_progress.md` flags that `neet.json` answer keys are not yet cross-referenced against official NTA keys. **Mitigation:** restrict the held-out 500 to NEET 2015–2025 (NTA-era, AKs publicly published). That gives us 2000+ Qs to sample from → 500 stratified is fine. AIPMT 2005–2014 stays in the corpus side but not in the eval set. *This is a deviation from the volt/idea mission spec, which assumed "any 500 from neetprep." I will flag this to the user and ask if it's OK before locking the split.*

### Hard-stop check

The mission says "if you cannot source 500 held-out from neetprep → STOP." We CAN: `neet.json` is the existing neetprep-derived dataset, and 2015–2025 NTA-era alone provides ~2000 candidates. No stop trigger. Eval set frozen as `scripts/offline_brain/eval/holdout_500.json` on day 2, committed to git, never touched again.

## 3. Compression ladder

Three sizes — 5MB, 2MB, 1MB — built for the **chosen primary candidate** (likely B). The other two candidates only get a 2MB build for the comparison table.

### Candidate B (static embeddings) ladder — **tiers tightened around 2 MB per soft-ceiling answer**

| Tier | Vocab × Dim × dtype | Index size (NCERT chunks) | Total | Technique applied |
|---|---|---|---|---|
| **2.5 MB** | 10k × 256 × int8 = 2.5 MB | + 50 KB | **~2.5 MB** | Mild vocab prune |
| **2.0 MB** ⭐ | 8k × 256 × int8 = 2.0 MB | + 50 KB | **~2.0 MB** | Syllabus-essential vocab (NCERT + Q-corpus TF) — **DECISION TIER** |
| **1.5 MB** | 6k × 256 × int8 = 1.5 MB | + 40 KB | **~1.5 MB** | Aggressive prune |

If 8k vocab is too tight (Hindi-loanword chemistry terms, IUPAC names, taxa), fall back to **8k × 192 int8 = 1.5 MB** with headroom for index. Will flag in results table if this branch is taken.

### Candidate A (TF-IDF) ladder

| Tier | Vocab | Chunks (N × ~600 char) | Total |
|---|---|---|---|
| **2.5 MB** | 16k IDF + 1800 chunks | 2.5 MB | TF-IDF in float16, chunks zstd |
| **2.0 MB** ⭐ | 12k IDF + 1500 chunks | 2.0 MB | Vocab + chunk prune |
| **1.5 MB** | 9k IDF + 1100 chunks | 1.5 MB | Aggressive |

### Candidate C (MiniLM-L2-128) — only the 2MB row built

Distill from `sentence-transformers/all-MiniLM-L6-v2` → 2-layer / 128-dim student. int8 quantize. Used **only** to compute a ceiling-comparison number.

### Source of NCERT syllabus chunks

NCERT publishes official PDF textbooks at `https://ncert.nic.in/textbook.php` under no DRM. Use **Class 11 + 12 Physics, Chemistry, Biology** (~14 books). Estimated ~2500 paragraph-level chunks after parsing. We will only commit chunk **embeddings + condensed text**, not the source PDFs.

**Open question for user:** are NCERT PDFs OK to use as the index corpus, or does Shivya have a preferred curated syllabus source? *(See §7.)*

## 4. Eval harness

### Location

`scripts/offline_brain/` (new directory, parallels existing `scripts/jee/`). Python 3 with `numpy`, `scikit-learn`, `sentence-transformers`, `model2vec`. Zero changes to the Flutter app in Phase B/C.

### Pipeline

```
holdout_500.json  ────┐
                      │
                      ▼
              for q in holdout:
                  q_vec   = encode(q.question_latex)
                  chunks  = topk(q_vec, ncert_index, k=3)
                  for opt in q.options:                     # 4 options
                      score[opt] = score_fn(opt, chunks, q)
                  picked = argmax(score)
                  log(q.id, picked, q.answer_key)

              top1 = mean(picked == answer_key)
```

### `score_fn` per candidate

| Candidate | score(option, chunks, q) |
|---|---|
| A (TF-IDF) | BM25(option ⊕ q.question_latex, chunks) |
| B (static) | cos(encode(option ⊕ q.question_latex), mean(chunks_vec)) |
| C (MiniLM) | same as B, with transformer encode |

### Metrics

1. **Top-1 accuracy** (primary, the kill criterion is on this)
2. **Per-subject accuracy** (Physics / Chemistry / Biology — biology will likely be highest, physics lowest; subject-disaggregation prevents a single-subject collapse from passing the gate)
3. **Per-year-bucket accuracy** (sanity check)
4. **Latency** — wall-clock per Q (we'll port the candidate B index to a tiny Dart prototype on day 6 to measure on a real Android, not Python)
5. **Calibration** — share of high-confidence (margin >0.2) picks vs their accuracy (lets us decide if we ship "I don't know" fallback)

### Output

`scripts/offline_brain/results/<candidate>_<tier>.json` per run + a final `RESULTS_TABLE.md`.

## 5. Integration sketch (Phase D only — for reference)

**No Flutter code changes in Phase B or C.** This section exists to anchor what BUILD would mean.

```
lib/services/offline_brain.dart      ← NEW (Phase D)
    class OfflineBrain {
      static Future<OfflineBrain> load(String assetPath);
      Future<BrainAnswer> answer(Question q);
    }
    class BrainAnswer { String optionLetter; double confidence; List<String> chunks; }

assets/offline_brain.bin              ← NEW (~2 MB binary blob, bundled in APK)
    [vocab][embeddings][ncert_chunks][index_metadata]

lib/screens/quiz_screen.dart          ← MODIFY (add "Ask AI" button, Phase D only)
```

The brain blob is small enough to bundle in the APK (current APK is 70 MB; +2 MB is negligible) — no `data.zip` sync needed.

## 6. 7-day timeline

| Day | Date | Milestone |
|---|---|---|
| 1 | **2026-05-29 (today)** | Plan written. User approves. Scaffold `scripts/offline_brain/`. Stop. |
| 2 | 2026-05-30 | Build held-out split. Parse NCERT PDFs to chunks. Build & eval candidate A (TF-IDF) at 5MB → baseline number. |
| 3 | 2026-05-31 | Build candidate B at 5MB and 2MB. Eval both. Commit best B-config. |
| 4 | 2026-06-01 | Distill candidate C → 2MB. Eval. Lock decision on which candidate goes to ladder runs. |
| 5 | 2026-06-02 | Run primary candidate at 2.5MB / 2.0MB / 1.5MB. Generate results table. |
| 6 | 2026-06-03 | Port 2MB candidate to a tiny Dart prototype. Measure latency on emulator + (if available) physical low-end Android. |
| 7 | 2026-06-04 | Phase D decision write-up to `decision_log.md`. **BUILD / KILL / EXTEND.** If BUILD: open a branch `offline-brain-v0.1` with the Flutter scaffold (no UI). |

Buffer day to deadline (2026-06-05): 1 day. Tight but feasible.

## 7. Locked decisions (user-answered 2026-05-29)

1. **Eval split:** NTA-era only (NEET 2015–2025). Holdout 500 drawn from ~2000 candidates. AIPMT 2005–2014 stays in the corpus side, never in eval.
2. **Index corpus:** Open NCERT PDFs (Class 11 + 12 Physics, Chemistry, Biology) from ncert.nic.in. ~14 books → est. ~2500 chunks.
3. **Python deps:** approved — `scikit-learn`, `sentence-transformers`, `model2vec`, `numpy`, `tqdm` in `scripts/offline_brain/requirements.txt`. Dev-time only. No new Flutter deps in Phase B/C.
4. **2MB ceiling: SOFT.** Report 2.5 MB / 2.0 MB / 1.5 MB tiers. **The BUILD/KILL decision is made on the 2.0 MB row.** Adjacent tiers are reported as context, not as alternate ship targets.

## 8. What this plan deliberately does NOT do

- ❌ Touch any `lib/` code in Phase B/C.
- ❌ Refactor anything in questionx that isn't a clean new directory under `scripts/` or `docs/`.
- ❌ Change the diagram pipeline or any in-progress audit work.
- ❌ Open the offline brain to user-typed free-form questions (it answers MCQs only — the eval surface).
- ❌ Generate any practice questions with an LLM. The held-out 500 is real audited PYQ data.
- ❌ Switch base models after day 4.
- ❌ Promise integration before the 2MB row of the results table is in.

## 9. Stop conditions reminder

| Condition | Action |
|---|---|
| 2MB top-1 < 85% on held-out 500 | **KILL.** Log reason. Revert any non-essential changes. |
| > 7 elapsed days from session start | **TIMEOUT.** Write log entry. |
| Want to refactor app core / change diagram pipeline / build new app | **STOP.** Park idea, do not pivot. |
| Cannot source 500 held-out from neet.json + NCERT | **STOP, ask user.** Do NOT use LLM-synthetic Qs. |
| External API call > $20 | **Ask user.** |

## 10. Awaiting

Your "go" + answers to §7 (1–4) before I start day 2.
