# `questionx-offline-brain` v0.1 — Results table

> Decision row is **2.0 MB tier**. Mission gate: ≥85% top-1 on the 500-Q NEET 2015-2025 held-out split. Decided: **KILL** on 2026-05-29 (day 2-3 of the 7-day window).

## Single table

| # | Candidate | Variant | Size | Top-1 | Bio (250) | Chem (125) | Phy (125) |
|---|---|---|---|---|---|---|---|
| baseline | Random | always "A" | 0 | **25.0%** | — | — | — |
| A | TF-IDF + BM25 | per-option retrieval, uncapped | 3.1 MB | **33.2%** | 34.8% | 39.2% | 24.0% |
| A | TF-IDF + BM25 | per-option, 2.5 MB tier | 2.5 MB | **31.0%** | 32.0% | 34.4% | 25.6% |
| A | **TF-IDF + BM25** | **per-option, 2.0 MB tier** ⭐ | **2.0 MB** | **29.4%** | 31.2% | 32.8% | 22.4% |
| A | TF-IDF + BM25 | per-option, 1.5 MB tier | 1.5 MB | **28.8%** | 30.4% | 30.4% | 24.0% |
| A | substring match | rare-term-weighted, uncapped | ~3.1 MB | **29.4%** | 35.2% | 27.2% | 20.0% |
| B | Static embed (model2vec) | potion-base-2M, qopt | 2.3 MB | **25.6%** | 28.0% | 29.6% | 16.8% |
| B | Static embed (model2vec) | potion-base-2M, opt | 2.3 MB | **27.0%** | 30.0% | 30.4% | 17.6% |
| B | Static embed (model2vec) | potion-base-8M, qopt | 8.5 MB | **26.0%** | 32.8% | 24.0% | 14.4% |
| B | Static embed (model2vec) | potion-base-8M, opt | 8.5 MB | **26.4%** | 30.0% | 29.6% | 16.0% |
| C | **MiniLM-L6 (ceiling)** | **uncapped, qopt — no size constraint** | **~80 MB** | **29.6%** | 34.0% | 28.8% | 21.6% |
| D | **Generative LM (SmolLM2-135M)** | zero-shot logprob, fp16 | **256 MB (128× over)** | **24.4%** | 25.6% | 21.6% | 24.8% |
| D | **Generative LM (SmolLM2-360M)** | zero-shot logprob, fp16 | **700 MB (350× over)** | **25.6%** | 28.0% | 23.2% | 23.2% |

## What the numbers say

- **The ceiling is ~33% across every architecture tested**, including the uncapped 80 MB MiniLM-L6.
- **Gap to 85% gate: 52 percentage points.** At the 2.0 MB tier, 55.6 points.
- The 4× over-budget model (potion-8M) did **not** beat the 2 MB model (potion-2M). Worse, the random baseline (25%) is within 1-2 points of the static embedding results. Architecture, not size, is the bottleneck.
- Biology peaks at 35%, the lookup-friendliest subject. Physics floors at 14-25% — derivation kills it.
- TF-IDF beats every embedding-based approach at every tier. Lexical overlap is doing the heavy lifting that semantic similarity was supposed to do.

## Why retrieval-as-MCQ-answerer fails on NEET

1. **Distractors are designed to be semantically near-correct.** All 4 options share topic vocabulary. Similarity-to-context scores ~uniformly across A/B/C/D.
2. **Correct answers often aren't lexically present in NCERT.** Numerical answers ("$486$ J"), specific year/value/percentage, computed quantities. NCERT explains the *method*; the answer must be *derived*.
3. **Multi-step derivation is unrepresentable in a single retrieved chunk.** Physics in particular — the Q gives premises, the answer is the conclusion. No chunk contains the conclusion verbatim.
4. **Composition needs attention, not mean-pooling.** Static embeddings (one vector per subword, mean-pooled) cannot represent "A causes B but not C". They represent topic membership only.

## What this disproves precisely

The hypothesis: *"A ≤2MB on-device retrieval + tiny LM combo, indexing the NEET syllabus, can answer NEET-style questions at ≥85% top-1 accuracy on a held-out set of 500 real questions."*

Two specific failure modes:
- **No 2MB "tiny LM" exists that can do MCQ reasoning.** The smallest credible generative LMs (SmolLM-135M, Phi-3-mini) are 50-300 MB at int4. The hypothesis's premise ("a tiny LM that fits in 2MB and reasons") doesn't match what tiny LMs are.
- **Retrieval-only without an LM tops out at ~33%** regardless of model size. We proved this with the uncapped MiniLM ceiling.

## What was NOT tried (parked, not pivots)

- Generative tiny LM (SmolLM-135M at int4 ≈ 50 MB). **Out of size budget by 25×.**
- Q-corpus retrieval (use the corpus-side 3356 NEET Qs as the index instead of NCERT). **Forbidden by the eval design** — that becomes "find the similar PYQ" not "know the syllabus."
- Hybrid retrieve-then-LM with the model running off-device (cloud API). **Out of "offline" scope.**

## Salvage value (artifacts that survive KILL)

- `scripts/offline_brain/eval/holdout_500.json` — frozen 500-Q NEET 2015-2025 stratified eval set with manifest. Reusable for any future on-device experiment.
- `scripts/offline_brain/ncert/chunks.json` — 4133 paragraph-chunked NCERT 11+12 Phy/Chem/Bio corpus. Reusable as a syllabus search index (different feature, different decision).
- The eval harness pattern in `candidates/` — pluggable scorer interface for future bake-offs.

These artifacts are committed but not integrated into the Flutter app. No Flutter changes shipped or proposed.

## Honest read on the gap

Even if we relaxed the 85% gate to 60% (still useful for a "study buddy"), we'd be 27 points short. The gap isn't a tuning problem; it's a category problem. Retrieval isn't the right primitive for NEET MCQ answering — generative reasoning is, and that needs >>2 MB of weights.

A future "offline AI for NEET" would need either:
- A genuinely small generative LM (Phi-3-mini, int4, ~2 GB) — out of scope of this hypothesis, but worth a separate evaluation later.
- A bespoke distilled model trained on NEET Q→answer pairs — substantial data + training cost, multi-month not multi-day.
- Cloud inference with offline cache — defeats "offline brain" premise.

## Day-4 EXTEND: generative tiny LM ceiling

User overrode the day-3 KILL with: "run a generative tiny LM. If that still doesn't lift, then KILL."

Ran SmolLM2-135M and SmolLM2-360M in zero-shot logprob-pick mode (the standard MCQ eval for autoregressive LMs):

| Model | Size (fp16) | Top-1 |
|---|---|---|
| SmolLM2-135M | 256 MB (128× the 2 MB budget) | **24.4%** |
| SmolLM2-360M | 700 MB (350× the 2 MB budget) | **25.6%** |

**Both are at-or-below random (25%).** SmolLM2-135M is slightly *below* chance. SmolLM2-360M (2.6× larger) lifts accuracy by 1.2 points — a trajectory that says even multi-GB models won't reach 85% on this task without domain-specific training.

This closes the generative direction too:
- 135M and 360M tiny LMs can do general English fluency but lack NEET-specific knowledge.
- Their weights don't contain the dense factual recall NCERT does, AND they lack the reasoning depth a 7B+ model has.
- Scaling tiny LMs into the "small but capable" range (1-2 B) puts us at multi-GB sizes, the opposite of "offline brain."

**Final decision: KILL.** Both retrieval and generative architectures fail at every size tried. The hypothesis premise (2 MB blob → 85% NEET accuracy) was structurally wrong.
