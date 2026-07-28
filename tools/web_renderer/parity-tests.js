/*
 * parity-tests.js — the phone's own test cases (test/tex_sanitize_test.dart),
 * ported 1:1 and run in the browser on load. If any FAIL, the JS pipeline has
 * drifted from the phone and the page shows a red banner. Green = web == phone.
 *
 * NOTE: inputs are written as plain single-quoted strings with doubled
 * backslashes — NOT template literals — because the LaTeX contains `${` (from
 * `$${...}$$` math) which a template literal would try to interpolate.
 */
(function () {
  const P = window.QXPipeline;
  const results = [];
  function t(name, fn) {
    try { fn(); results.push({ name, ok: true }); }
    catch (e) { results.push({ name, ok: false, msg: e.message }); }
  }
  const contains = (s, sub) => { if (!String(s).includes(sub)) throw new Error('expected to contain «' + sub + '» — got «' + s + '»'); };
  const notContains = (s, sub) => { if (String(s).includes(sub)) throw new Error('expected NOT to contain «' + sub + '» — got «' + s + '»'); };
  const startsWith = (s, sub) => { if (!String(s).startsWith(sub)) throw new Error('expected to start with «' + sub + '» — got «' + s + '»'); };
  const endsWith = (s, sub) => { if (!String(s).endsWith(sub)) throw new Error('expected to end with «' + sub + '» — got «' + s + '»'); };
  const notStartsWith = (s, sub) => { if (String(s).startsWith(sub)) throw new Error('expected NOT to start with «' + sub + '» — got «' + s + '»'); };
  const equals = (s, exp) => { if (String(s) !== exp) throw new Error('expected «' + exp + '» — got «' + s + '»'); };

  const S = P.sanitize, M = P.mergeChemReactions;

  // --- _sanitize \over handling ---
  t('over: does NOT mangle \\over* commands', () => {
    const out = S('\\left| {\\overrightarrow R } \\right| = \\left| {\\overrightarrow P } \\right|');
    contains(out, '\\overrightarrow R');
    contains(out, '\\overrightarrow P');
    notContains(out, '\\frac');
  });
  t('over: leaves other \\over* commands intact', () => {
    for (const cmd of ['{\\overline x}', '{\\overbrace{abc}}', '{\\overleftarrow v}']) {
      notContains(S(cmd), '\\frac');
    }
  });
  t('over: STILL converts genuine {a \\over b} to \\frac', () => {
    const out = S('{2P\\sin \\theta \\over Q + 2P\\cos \\theta}');
    startsWith(out, '\\frac{');
    contains(out, '\\sin');
    notContains(out, '\\over ');
  });

  // --- legacy-TeX recovery ---
  t('gathered -> aligned', () => {
    const out = S('\\begin{gathered}a\\\\b\\end{gathered}');
    contains(out, '\\begin{aligned}');
    notContains(out, 'gathered');
  });
  t('\\matrix{..} -> \\begin{matrix}..\\end{matrix}', () => {
    const out = S('\\matrix{1 & 2 \\cr 3 & 4}');
    contains(out, '\\begin{matrix}');
    contains(out, '\\end{matrix}');
    notContains(out, '\\matrix{');
  });
  t('strips \\limits/\\tag, maps \\AA and \\cdotp', () => {
    notContains(S('\\int_\\limits0^1'), '\\limits');
    notContains(S('x=1\\tag{3}'), '\\tag');
    contains(S('\\text{5 \\AA}'), 'Å');
    contains(S('a\\cdotp b'), '\\cdot');
  });

  // --- mergeChemReactions ---
  t('merges fragmented reaction M(s)+half O2 -> MO(s)', () => {
    const out = M('M(s) + $${1 \\over 2}$$ $O_{2}(g)$ $$ \\to $$ MO(s)');
    startsWith(out, '$$');
    endsWith(out, '$$');
    contains(out, '\\text{M(s) + }');
    contains(out, '\\text{ MO(s)}');
    contains(out, '\\to');
    contains(out, 'O_{2}(g)');
    notContains(out.substring(2, out.length - 2), '$$');
  });
  t('merges electrochemistry half-reaction', () => {
    const out = M('$Zn^{2+}$ + $2e^{–}$ $$ \\to $$ Zn(s) ; $E^{o}$ = – 0.76 V');
    startsWith(out, '$$');
    contains(out, 'Zn^{2+}');
    contains(out, '\\to');
    contains(out, '\\text{ Zn(s) ; }');
  });
  t('merges multi-species reaction', () => {
    const out = M('$2N_{2}O_{5}(g)$ $$ \\to $$ $4NO_{2}(g)$ + $O_{2}(g)$.');
    startsWith(out, '$$');
    contains(out, '2N_{2}O_{5}(g)');
    contains(out, '\\to');
    contains(out, '4NO_{2}(g)');
  });
  t('does NOT merge non-chemistry arrow lines to $$\\text', () => {
    const out = M('$$\\to$$ So we can say if an acid forms more $H^{+}$ ion');
    notStartsWith(out, '$$\\text');
  });
  t('does NOT merge lines without arrows', () => {
    const input = 'The value of $K_{p}$ at 300 K is 100.0';
    equals(M(input), input);
  });
  t('collapses newlines', () => {
    equals(M('Line one\n\nLine two\n\n\nLine three'), 'Line one\nLine two\nLine three');
  });
  t('handles the reported multi-line reaction question', () => {
    const input =
      'The plot shows the variation of −$$ln$$ $K_{p}$ versus ' +
      'temperature for the two reactions.\n\n' +
      'M(s) + $${1 \\over 2}$$ $O_{2}(g)$ $$ \\to $$ MO(s) and \n\n' +
      'C(s) + $${1 \\over 2}$$ $O_{2}(g)$ $$ \\to $$ CO(g)\n\n' +
      'Identify the correct statement :';
    const out = M(input);
    notContains(out, '\n\n');
    contains(out, '\\text{M(s) + }');
    contains(out, '\\text{C(s) + }');
    contains(out, 'The plot shows');
    contains(out, 'Identify the correct statement');
  });
  t('escapes braces in plain text', () => {
    const out = M('A{s} + $B_{2}(g)$ $$ \\to $$ C(g)');
    contains(out, 'A\\{s\\}');
  });

  window.QXParityResults = results;
})();
