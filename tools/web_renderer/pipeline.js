/*
 * pipeline.js — a FAITHFUL JavaScript port of the phone's rendering pipeline.
 *
 * Ported 1:1 from lib/widgets/tex_view.dart and lib/utils/answer_grading.dart.
 * The goal is byte-identical preprocessing output so the web page shows the
 * SAME rendering (including the same breakage) a user sees on the phone.
 *
 * Phone renders math with flutter_math_fork (a KaTeX subset); the browser uses
 * KaTeX, so the visual result is a near-exact match.
 *
 * If you change tex_view.dart, mirror the change here and re-run the parity
 * self-test (see parity-tests.js) to confirm the port still matches.
 */

// A fresh regex each call — a shared /g regex carries lastIndex between calls
// and would corrupt the exec() loops below.
function mathPattern() {
  return /\$\$([\s\S]+?)\$\$|\$([\s\S]+?)\$/g; // dotAll via [\s\S]; group1=$$display$$, group2=$inline$
}

// --------------------------------------------------------------------------
// Chemistry reaction merger  (tex_view.dart:36-106)
// --------------------------------------------------------------------------

function mergeChemReactions(input) {
  // Collapse \n\n+ → \n for compact rendering on small screens.
  let s = input.replace(/\n{2,}/g, '\n');
  const lines = s.split('\n');
  const out = [];
  for (const line of lines) {
    out.push(_isFragmentedReaction(line) ? _mergeReactionLine(line) : line);
  }
  return out.join('\n');
}

function _isFragmentedReaction(line) {
  // Must have a reaction arrow inside math delimiters.
  if (!/\$\$\s*\\(?:to|rightarrow)\s*\$\$/.test(line)) return false;
  // Must show chemical notation: state symbols, subscripts, or ion charges.
  if (!/\([slg]\)|\(aq\)|_\{|\^\{[0-9]*[+-]/.test(line)) return false;
  // Must have ≥ 4 non-empty segments to benefit from merging.
  let count = 0, last = 0, m;
  const re = mathPattern();
  while ((m = re.exec(line)) !== null) {
    const start = m.index, end = m.index + m[0].length;
    if (start > last && line.substring(last, start).trim() !== '') count++;
    count++;
    last = end;
  }
  if (last < line.length && line.substring(last).trim() !== '') count++;
  return count >= 4;
}

function _mergeReactionLine(line) {
  let buf = '', last = 0, m;
  const re = mathPattern();
  while ((m = re.exec(line)) !== null) {
    const start = m.index, end = m.index + m[0].length;
    if (start > last) {
      const plain = line.substring(last, start);
      if (plain.trim() !== '') buf += '\\text{' + _texEscape(plain) + '}';
    }
    // Unwrap: group(1) is display $$..$$, group(2) is inline $..$
    const tex = (m[1] != null ? m[1] : (m[2] != null ? m[2] : '')).trim();
    if (tex !== '') buf += ' ' + tex + ' ';
    last = end;
  }
  if (last < line.length) {
    const tail = line.substring(last);
    if (tail.trim() !== '') buf += '\\text{' + _texEscape(tail) + '}';
  }
  return '$$' + buf + '$$';
}

function _texEscape(s) {
  return s.replace(/\{/g, '\\{').replace(/\}/g, '\\}');
}

// --------------------------------------------------------------------------
// LaTeX sanitizer  (tex_view.dart:114-181)
// --------------------------------------------------------------------------

function sanitize(t) {
  let s = t;
  s = s.replace(/\\n/g, ' '); // literal backslash-n artifacts
  s = s.replace(/\\(displaystyle|scriptstyle|textstyle|scriptscriptstyle)\b/g, '');
  s = s.replace(/\\(raise|lower)[0-9.]+ex/g, '');
  s = s.replace(/\\kern-?[0-9.]+em/g, '');
  s = s.replace(/\\hbox\{([^{}]*)\}/g, (m, a) => '\\text{' + a + '}');
  s = s.replace(/\\operatorname\s*\{([^{}]*)\}/g, (m, a) => '\\mathrm{' + a + '}');
  // {a \over b} -> \frac{a}{b}. Negative lookahead so \overrightarrow etc. survive.
  for (let i = 0; i < 4; i++) {
    if (!/\{([^{}]*)\\over(?![a-zA-Z])([^{}]*)\}/.test(s)) break;
    s = s.replace(/\{([^{}]*)\\over(?![a-zA-Z])([^{}]*)\}/g,
      (m, a, b) => '\\frac{' + a + '}{' + b + '}');
  }
  s = s.replace(/\\begin\{gathered\}/g, '\\begin{aligned}')
       .replace(/\\end\{gathered\}/g, '\\end{aligned}');
  s = s.replace(/\\(no)?limits(?![a-zA-Z])/g, '');
  s = s.replace(/\\tag\s*\{[^{}]*\}/g, '');
  s = s.replace(/\\AA(?![a-zA-Z])/g, 'Å');
  s = s.replace(/\\cdotp(?![a-zA-Z])/g, '\\cdot');
  s = _convertMatrix(s);
  return s;
}

function _convertMatrix(s) {
  for (const name of ['pmatrix', 'bmatrix', 'matrix']) {
    const open = new RegExp('\\\\' + name + '\\s*\\{');
    for (let guard = 0; guard < 50; guard++) {
      const m = open.exec(s);
      if (!m) break;
      const openEnd = m.index + m[0].length;
      let depth = 1, i = openEnd;
      while (i < s.length && depth > 0) {
        if (s[i] === '{') depth++;
        else if (s[i] === '}') depth--;
        i++;
      }
      const inner = s.substring(openEnd, i - 1);
      s = s.substring(0, m.index) + '\\begin{' + name + '}' + inner +
          '\\end{' + name + '}' + s.substring(i);
    }
  }
  return s;
}

// --------------------------------------------------------------------------
// Plain-text fallback  (tex_view.dart:185-204)
// --------------------------------------------------------------------------

// Insertion order matters (matches the Dart Map exactly).
const _FALLBACK_SYMBOLS = [
  ['\\times', '×'], ['\\cdot', '·'], ['\\pm', '±'], ['\\div', '÷'], ['\\sqrt', '√'],
  ['\\theta', 'θ'], ['\\alpha', 'α'], ['\\beta', 'β'], ['\\gamma', 'γ'], ['\\mu', 'μ'],
  ['\\pi', 'π'], ['\\omega', 'ω'], ['\\lambda', 'λ'], ['\\Delta', 'Δ'], ['\\sigma', 'σ'],
  ['\\infty', '∞'], ['\\rightarrow', '→'], ['\\circ', '°'], ['\\le', '≤'], ['\\ge', '≥'],
  ['\\sin', 'sin'], ['\\cos', 'cos'], ['\\tan', 'tan'], ['\\log', 'log'],
];

function plainFallback(tex) {
  let s = tex.replace(/\\n/g, ' ');
  s = s.replace(/\\frac\{([^{}]*)\}\{([^{}]*)\}/g, (m, a, b) => '(' + a + ')/(' + b + ')');
  s = s.replace(/\\sqrt\s*\{([^{}]*)\}/g, (m, a) => '√(' + a + ')');
  for (const [k, v] of _FALLBACK_SYMBOLS) {
    s = s.split(k).join(v); // replaceAll of a literal string
  }
  s = s.replace(/\\[a-zA-Z]+/g, '')
       .replace(/[{}$]/g, '')
       .replace(/\s+/g, ' ')
       .trim();
  return s;
}

// --------------------------------------------------------------------------
// KaTeX render of a single math segment (mirrors _mathBox onErrorFallback)
// --------------------------------------------------------------------------

function renderMathInto(el, tex, isDisplay) {
  const cleaned = sanitize(tex);
  try {
    if (typeof katex === 'undefined') throw new Error('katex-not-loaded');
    katex.render(cleaned, el, {
      displayMode: isDisplay,
      throwOnError: true, // force the fallback path exactly like the phone
      strict: false,
    });
    el.dataset.rendered = 'ok';
  } catch (e) {
    // Phone degrades to readable plain text using the ORIGINAL (unsanitized) tex.
    el.textContent = plainFallback(tex);
    el.classList.add('math-fallback');
    el.dataset.rendered = 'fallback';
  }
}

// --------------------------------------------------------------------------
// Full field render: mergeChem → split on $$..$$/$..$ → math|text
// Mirrors TexText.build (tex_view.dart:210-234).
// Returns {node, mathCount, fallbackCount} so the UI can badge broken cards.
// --------------------------------------------------------------------------

function renderField(rawText) {
  const wrap = document.createElement('div');
  wrap.className = 'texfield';
  let mathCount = 0, fallbackCount = 0;

  if (rawText == null || rawText === '') {
    return { node: wrap, mathCount, fallbackCount };
  }

  const processed = mergeChemReactions(rawText);
  const re = mathPattern();
  let last = 0, m;
  const appendPlain = (str) => {
    if (str === '') return;
    const span = document.createElement('span');
    span.className = 'plain';
    span.textContent = str; // CSS white-space: pre-wrap honours \n
    wrap.appendChild(span);
  };

  while ((m = re.exec(processed)) !== null) {
    const start = m.index, end = m.index + m[0].length;
    if (start > last) appendPlain(processed.substring(last, start));
    const isDisplay = m[1] != null;
    const tex = (m[1] != null ? m[1] : (m[2] != null ? m[2] : '')).trim();
    if (tex !== '') {
      const span = document.createElement('span');
      span.className = isDisplay ? 'math math-display' : 'math math-inline';
      renderMathInto(span, tex, isDisplay);
      if (span.dataset.rendered === 'fallback') fallbackCount++;
      mathCount++;
      wrap.appendChild(span);
    }
    last = end;
  }
  if (last < processed.length) appendPlain(processed.substring(last));

  return { node: wrap, mathCount, fallbackCount };
}

// --------------------------------------------------------------------------
// Answer grading  (lib/utils/answer_grading.dart)
// --------------------------------------------------------------------------

const QType = { mcqSingle: 'mcqSingle', mcqMulti: 'mcqMulti', numeric: 'numeric', bonus: 'bonus' };

function typeOf(options, answerKey) {
  const ak = (answerKey || '').trim();
  const hasOptions = (options || []).some((o) => (o || '').trim() !== '');
  if (!hasOptions) {
    if (/^bonus$/i.test(ak)) return QType.bonus;
    return QType.numeric;
  }
  return ak.includes(',') ? QType.mcqMulti : QType.mcqSingle;
}

function correctAnswerText(type, answerKey) {
  const ak = (answerKey || '').trim();
  switch (type) {
    case QType.bonus: return 'Bonus — all answers accepted';
    case QType.numeric:
      return ak.replace(/[$\\]/g, '').replace(/TO/g, ' to ').replace(/OR/g, ' or ');
    default: return ak.toUpperCase();
  }
}

// Which option indices are correct (for MCQ highlighting). "A"→[0], "A,C"→[0,2].
function correctOptionIndices(answerKey) {
  const ak = (answerKey || '').trim().toUpperCase();
  const idx = [];
  for (const part of ak.split(/[,\s]+/)) {
    if (part.length === 1 && part >= 'A' && part <= 'Z') {
      idx.push(part.charCodeAt(0) - 65);
    }
  }
  return idx;
}

// Expose for the browser (no modules — plain script tags).
window.QXPipeline = {
  mergeChemReactions, sanitize, plainFallback, renderField, renderMathInto,
  typeOf, correctAnswerText, correctOptionIndices, QType,
  // test-only internals
  _isFragmentedReaction, _mergeReactionLine, _convertMatrix,
};
