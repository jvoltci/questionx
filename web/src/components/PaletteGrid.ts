import { QuizState } from "../state/quizState";

export function renderPaletteGrid(state: QuizState): string {
  const buttons = state.questions
    .map((q, idx) => {
      const status = state.getStatus(q.id);
      const isCurrent = state.currentIndex === idx;
      let btnClass = `palette-btn ${status}`;
      if (isCurrent) btnClass += " current";

      return `
      <button class="${btnClass}" data-goto-index="${idx}" title="Go to question ${idx + 1} (${status})">
        ${idx + 1}
      </button>
    `;
    })
    .join("");

  const answeredCount = state.answers.size;
  const reviewCount = state.markedForReview.size;
  const unvisitedCount = Math.max(0, state.questions.length - state.visited.size);
  const unansweredCount = Math.max(0, state.visited.size - answeredCount);

  return `
    <div>
      <div style="font-weight: 750; font-size: 1rem; margin-bottom: 0.75rem; display: flex; justify-content: space-between; align-items: center;">
        <span style="color: var(--ink-max);">Question Palette</span>
        <span style="font-size: 0.82rem; font-weight: 600; color: var(--neutral-11);">${state.questions.length} Items</span>
      </div>

      <div class="palette-legend">
        <div class="palette-legend-item">
          <div class="palette-legend-dot" style="background: var(--cbt-answered-bg);"></div>
          <span>Answered (${answeredCount})</span>
        </div>
        <div class="palette-legend-item">
          <div class="palette-legend-dot" style="background: var(--cbt-review-bg);"></div>
          <span>Review (${reviewCount})</span>
        </div>
        <div class="palette-legend-item">
          <div class="palette-legend-dot" style="background: var(--cbt-notvisited-bg);"></div>
          <span>Unvisited (${unvisitedCount})</span>
        </div>
        <div class="palette-legend-item">
          <div class="palette-legend-dot" style="background: var(--cbt-unanswered-bg);"></div>
          <span>Unanswered (${unansweredCount})</span>
        </div>
      </div>

      <div class="palette-grid-matrix">
        ${buttons}
      </div>
    </div>
  `;
}
