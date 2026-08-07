# Cross-exam practice for NEET Physics & Chemistry

**Status:** approved, in implementation
**Origin:** user report (SAMYAK GAIKWAD, 6 Aug 2026) asking for JEE Main Physics/Chemistry
questions inside the NEET experience.

## Problem

Two problems, and the smaller one is the one that was reported.

**1. NEET topic practice barely works for Chemistry.** The NEET bank's topic
taxonomy is fragmented to the point of being unusable:

| | topics | topics with <5 Qs | median Qs/topic |
|---|---|---|---|
| NEET Physics | 61 | 26 | 10 |
| NEET Chemistry | 109 | 72 | **2** |

A student selecting a Chemistry topic today gets a median of **two questions**.
The taxonomy also contains four spellings of "Dual Nature of ..." and a typo
(`Kinsctic Theory of Gases`), so questions on one concept are split across
several unrelated-looking buckets.

**2. 9,520 relevant questions ship on every device and cannot be reached.** The
JEE bank holds 5,141 Physics and 4,379 Chemistry questions. NEET and JEE Main
share roughly 85–90% of their Physics and Chemistry syllabi, so nearly all of it
is on-syllabus for a NEET student. It is already scraped, verified, encrypted and
downloaded — it is simply invisible to anyone practising NEET.

```
Physics     967  ->  6,108   (6.3x)
Chemistry   942  ->  5,321   (5.6x)
Biology   1,927  ->  unchanged (no JEE equivalent)
```

## What this is NOT

The request was framed as "NEET level has increased, give me harder questions".
**That premise does not survive the data.** By the bank's own difficulty labels:

| | Easy | Medium | Hard |
|---|---|---|---|
| NEET Phy+Chem | 49% | 45% | 4% |
| JEE **Main** Phy+Chem | 46% | 49% | 3% |
| JEE **Advanced** Phy+Chem | 14% | 61% | **24%** |

JEE Main is statistically indistinguishable from NEET. So the feature is sold as
**more practice on the same syllabus**, never as "harder". Students who want hard
questions use the existing difficulty filter, which this makes usable for the
first time:

```
"Hard" Phy+Chem questions reachable:   84  ->  413   (4.9x)
```

JEE Advanced is included in the pool for exactly this reason, and badged
distinctly so a student always knows what they are attempting.

## Design

### Topic map

`lib/data/cross_exam_topics.dart` — a const map keyed by **JEE topic**, listing
the NEET topics each one covers.

Keyed by JEE deliberately: JEE has 32 clean topics per subject, NEET has 61 and
109 messy ones. Mapping from the NEET side would be 170 entries to curate and
review; from the JEE side it is 64, and the inversion (NEET topic -> JEE topics)
is computed once at runtime.

A test asserts every JEE Physics/Chemistry topic appears in the map, so a
re-scrape that introduces a topic fails the build rather than silently dropping
its questions — the same ratchet used for `data.zip` diagram coverage.

The lookup is scoped by subject, not topic name alone: `Biomolecules` is a topic
in NEET **Biology** as well as NEET Chemistry, and an unscoped inversion would let
a Biology selection reach for JEE Chemistry questions.

### Query

`getCustomQuestions` gains `crossExamTopics`. The predicate becomes an OR of two
exam-scoped groups:

```
(examName LIKE '<exam>%' AND topic IN <selected topics>)
OR
(examName LIKE 'JEE%'    AND topic IN <mapped topics>)
```

`_dedupeByContent` already runs on the result. Cross-bank duplication measured at
15 questions, so this is a non-issue but costs nothing.

Biology never maps, so it is unaffected without special-casing.

### UI

**Practice setup** — a switch shown only for Physics/Chemistry, **off by
default**, persisted in prefs so a student sets it once. Label: *"Include JEE
questions — same syllabus, more practice"*, with a live count.

**Thin-pool nudge** — when the selected topics yield fewer than 10 NEET
questions, an inline prompt offers to add the JEE pool, stating both numbers.
This is what carries the benefit to students who never go looking for a switch,
without silently changing the product under anyone. It is a prompt, not a
default: the student still chooses.

**Badge** — `SourceExamBadge`, shown above the question stem. It appears only
when the practice set actually spans more than one exam, so a plain NEET or plain
JEE session carries no extra chrome and no exam needs to be plumbed down into the
quiz screen. JEE Advanced gets its own colour from JEE Main, because it is the
genuinely harder pool and a student should be able to tell them apart at a
glance.

### Out of scope

No new home-screen section or tab. No new content pipeline. No Biology handling.
No re-rating of question difficulty.

## Testing

- every JEE Phy/Chem topic is mapped (build-failing ratchet)
- every mapped NEET topic name exists in the NEET bank (catches typos in the map)
- query returns both exams for a mapped topic, and NEET only when the flag is off
- Biology unaffected
- badge renders for JEE rows only

## Risk

A student who is ambushed by off-syllabus questions loses trust in the bank. The
mitigations are: off by default, an explicit prompt rather than a silent default,
a visible badge on every JEE question, and a curated map reviewed by the owner
rather than fuzzy name matching.
