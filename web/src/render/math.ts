import katex from "katex";

/**
 * Parses a string containing LaTeX ($...$ and $$...$$) and replaces math expressions
 * with KaTeX HTML output. Regular text has basic HTML entities escaped.
 */
export function renderLatexToHtml(text: string): string {
  if (!text) return "";

  // Split on display math $$...$$ first, then inline math $...$
  const parts: string[] = [];
  let remaining = text;

  // Pattern for display math ($$...$$, \[...\]) and inline math ($...$, \(...\))
  const regex = /(\$\$[\s\S]*?\$\$|\\\[[\s\S]*?\\\]|\$[^\$\n]+?\$|\\\([\s\S]*?\\\))/g;
  let lastIndex = 0;
  let match: RegExpExecArray | null;

  while ((match = regex.exec(remaining)) !== null) {
    // Normal text before match
    if (match.index > lastIndex) {
      const normalText = remaining.substring(lastIndex, match.index);
      parts.push(escapeHtml(normalText).replace(/\n/g, "<br/>"));
    }

    const rawMatch = match[0];
    let isDisplay = false;
    let mathContent = rawMatch;

    if (rawMatch.startsWith("$$") && rawMatch.endsWith("$$")) {
      mathContent = rawMatch.slice(2, -2).trim();
      isDisplay = true;
    } else if (rawMatch.startsWith("\\[") && rawMatch.endsWith("\\]")) {
      mathContent = rawMatch.slice(2, -2).trim();
      isDisplay = true;
    } else if (rawMatch.startsWith("$") && rawMatch.endsWith("$")) {
      mathContent = rawMatch.slice(1, -1).trim();
    } else if (rawMatch.startsWith("\\(") && rawMatch.endsWith("\\)")) {
      mathContent = rawMatch.slice(2, -2).trim();
    }

    try {
      const rendered = katex.renderToString(mathContent, {
        displayMode: isDisplay,
        throwOnError: false,
      });
      parts.push(rendered);
    } catch {
      parts.push(escapeHtml(rawMatch));
    }

    lastIndex = match.index + rawMatch.length;
  }

  // Trailing text
  if (lastIndex < remaining.length) {
    const trailing = remaining.substring(lastIndex);
    parts.push(escapeHtml(trailing).replace(/\n/g, "<br/>"));
  }

  return parts.join("");
}

function escapeHtml(str: string): string {
  return str
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}
