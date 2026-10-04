import { QuizState } from "../state/quizState";
import { renderLatexToHtml } from "../render/math";

export function renderQuestionCard(state: QuizState): string {
  const q = state.currentQuestion;
  if (!q) return `<div class="glass-panel" style="padding: 2rem; border-radius: 16px; text-align: center;">No question available</div>`;

  const selectedIndex = state.answers.get(q.id);
  const isSubmitted = state.isSubmitted;
  const correctKey = q.answer_key?.trim().toUpperCase();

  // High-Res Diagram Rendering
  let diagramHtml = "";
  if (q.question_svg) {
    if (q.question_svg.trim().startsWith("<svg")) {
      diagramHtml = `<div class="cbt-diagram-frame">${q.question_svg}</div>`;
    } else {
      diagramHtml = `
        <div class="cbt-diagram-frame">
          <img src="diagrams/${q.question_svg}" alt="Question Diagram ${q.id}" loading="lazy" />
        </div>
      `;
    }
  }

  // Options Rendering with Tactile Feedback
  let optionsHtml = "";
  if (q.options && q.options.length > 0) {
    optionsHtml = q.options
      .map((opt, idx) => {
        const letter = String.fromCharCode(65 + idx);
        const isSelected = selectedIndex === idx;
        let optionClass = "cbt-option-item";
        if (isSelected) optionClass += " selected";

        if (isSubmitted) {
          if (letter === correctKey) {
            optionClass += " border-emerald-500 bg-emerald-500/15";
          } else if (isSelected && letter !== correctKey) {
            optionClass += " border-rose-500 bg-rose-500/15";
          }
        }

        return `
        <div class="${optionClass}" data-option-index="${idx}" role="button" tabindex="0" aria-label="Option ${letter}">
          <span class="cbt-opt-circle">${letter}</span>
          <div class="cbt-opt-content">${renderLatexToHtml(opt)}</div>
          ${isSelected ? `<span style="font-size: 0.85rem; color: var(--tulip-buttercup-9); font-weight: 700;">✓</span>` : ""}
        </div>
      `;
      })
      .join("");
  }

  // Detailed Solution Explanation
  let solutionHtml = "";
  if (isSubmitted && q.solution) {
    solutionHtml = `
      <div class="cbt-solution-panel">
        <div class="cbt-solution-header">
          <span>💡 Verified Step-by-Step Explanation</span>
        </div>
        <div style="font-size: 1.05rem; line-height: 1.65; color: var(--ink-reading);">
          ${renderLatexToHtml(q.solution)}
        </div>
      </div>
    `;
  }

  return `
    <div class="cbt-meta-bar">
      <div class="cbt-q-tag">
        <span>Question ${state.currentIndex + 1}</span>
        <span style="font-size: 0.85rem; font-weight: 500; color: var(--neutral-11);">of ${state.questions.length}</span>
        <span class="cbt-q-subject-badge">${q.subject}</span>
        ${q.year ? `<span style="font-size: 0.75rem; color: var(--neutral-11);">${q.year}</span>` : ""}
      </div>
      <div>
        <span style="font-size: 0.82rem; font-weight: 600; color: var(--neutral-11); letter-spacing: 0.02em;">Marks: +4, -1</span>
      </div>
    </div>

    <div class="cbt-stem-container">
      ${renderLatexToHtml(q.question_latex)}
    </div>

    ${diagramHtml}

    <div class="cbt-options-list">
      ${optionsHtml}
    </div>

    ${solutionHtml}
  `;
}
