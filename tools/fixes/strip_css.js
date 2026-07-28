/*
 * strip_css.js — remove leaked HTML/CSS stylesheet text from question fields.
 *
 * Commit 9bc933d stripped CSS from question_latex only; 100 solutions + 6
 * options still carry raw `.tg {border-collapse...}` rulesets. This defines a
 * TARGETED stripper (only fires on real CSS rulesets — a selector followed by a
 * brace block containing known CSS properties) and VALIDATES it against every
 * question so we can prove it never touches legitimate math/text.
 *
 * Run: node tools/fixes/strip_css.js         (report only, no writes)
 */
'use strict';

// CSS property names that never legitimately appear inside a LaTeX {...} group.
const CSS_PROPS =
  '(?:border-collapse|border-spacing|border-color|border-style|border-width|border|' +
  'font-family|font-size|font-weight|padding|margin|overflow|word-break|white-space|' +
  'text-align|vertical-align|background|color|display|width|height)';

// A CSS ruleset: an optional selector chain, then { ...props... } where the body
// contains at least one CSS property followed by a colon. Global + multiline.
const RULESET = new RegExp(
  '\\s*[.#]?[A-Za-z][\\w .,#:>()\\[\\]"\'=-]*\\{[^{}]*' + CSS_PROPS + '\\s*:[^{}]*\\}',
  'g'
);

function stripCss(text) {
  if (text == null) return text;
  let s = text;
  // Remove CSS rulesets wherever they appear.
  s = s.replace(RULESET, '');
  // Collapse the blank-line gap the removed <style> block leaves behind.
  s = s.replace(/\n{3,}/g, '\n\n').replace(/^\s+/, '');
  return s;
}

module.exports = { stripCss, RULESET };

// ---- validation harness ----
if (require.main === module) {
  const fs = require('fs');
  const data = JSON.parse(fs.readFileSync('assets/jee.json', 'utf8'));
  let changed = 0, totalRemoved = 0;
  const samples = [];
  const suspicious = []; // changes that removed something with a $ or LaTeX command — a red flag

  for (const q of data) {
    for (const field of ['question_latex', 'solution']) {
      const before = q[field];
      if (before == null) continue;
      const after = stripCss(before);
      if (after !== before) {
        changed++;
        const removed = before.length - after.length;
        totalRemoved += removed;
        // did we remove any math? legit content would contain $ or \command
        const removedText = before.replace(after, ''); // rough
        if (/\$|\\[a-zA-Z]{2,}/.test(diff(before, after))) suspicious.push(q.id + ' :: ' + field);
        if (samples.length < 3) samples.push({ id: q.id, field, before: before.slice(0, 180), after: after.slice(0, 120) });
      }
    }
    for (let i = 0; i < (q.options || []).length; i++) {
      const before = q.options[i];
      const after = stripCss(before);
      if (after !== before) { changed++; totalRemoved += before.length - after.length; if (/\$|\\[a-zA-Z]{2,}/.test(diff(before, after))) suspicious.push(q.id + ' :: opt' + i); }
    }
  }

  // crude removed-portion extractor for the red-flag check
  function diff(b, a) {
    // find the longest chunk present in b but not a by walking the ruleset matches
    const parts = b.match(RULESET) || [];
    return parts.join(' ');
  }

  console.log('fields changed:', changed);
  console.log('total chars removed:', totalRemoved);
  console.log('SUSPICIOUS (removed something containing math):', suspicious.length);
  if (suspicious.length) console.log('  ', suspicious.slice(0, 20).join('\n   '));
  console.log('\n--- samples (before → after) ---');
  for (const s of samples) {
    console.log('\n[' + s.id + ' / ' + s.field + ']');
    console.log('  BEFORE:', JSON.stringify(s.before));
    console.log('  AFTER :', JSON.stringify(s.after));
  }
}
