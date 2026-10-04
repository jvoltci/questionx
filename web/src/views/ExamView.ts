import { QuizState } from "../state/quizState";
import { renderQuestionCard } from "../components/QuestionCard";
import { renderPaletteGrid } from "../components/PaletteGrid";
import { blossom } from "../effects/blossom";

export class ExamView {
  private container: HTMLElement;
  private state: QuizState;
  private title: string;
  private onExit: () => void;
  private timerInterval: number | null = null;
  private keydownHandler: ((e: KeyboardEvent) => void) | null = null;
  private unsubscribe: (() => void) | null = null;

  constructor(container: HTMLElement, state: QuizState, title: string, onExit: () => void) {
    this.container = container;
    this.state = state;
    this.title = title;
    this.onExit = onExit;
  }

  render() {
    this.startTimer();
    this.setupKeyboard();

    this.unsubscribe = this.state.subscribe(() => {
      this.updateUI();
    });

    this.renderFull();
  }

  destroy() {
    if (this.timerInterval) {
      clearInterval(this.timerInterval);
      this.timerInterval = null;
    }
    if (this.keydownHandler) {
      window.removeEventListener("keydown", this.keydownHandler);
      this.keydownHandler = null;
    }
    if (this.unsubscribe) {
      this.unsubscribe();
      this.unsubscribe = null;
    }
  }

  private startTimer() {
    if (this.timerInterval) clearInterval(this.timerInterval);
    this.timerInterval = window.setInterval(() => {
      if (this.state.isSubmitted) {
        clearInterval(this.timerInterval!);
        return;
      }

      if (this.state.timerSeconds > 0) {
        this.state.timerSeconds--;
        const timerEl = document.getElementById("cbt-timer-display");
        if (timerEl) {
          timerEl.textContent = this.formatTime(this.state.timerSeconds);
        }
      } else {
        clearInterval(this.timerInterval!);
        this.state.submit();
      }
    }, 1000);
  }

  private formatTime(totalSeconds: number): string {
    const m = Math.floor(totalSeconds / 60);
    const s = totalSeconds % 60;
    return `${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}`;
  }

  private setupKeyboard() {
    this.keydownHandler = (e: KeyboardEvent) => {
      // Ignore if typing in input
      if (e.target && /^(input|textarea)$/i.test((e.target as HTMLElement).tagName)) return;

      const key = e.key.toUpperCase();

      if (key === "1" || key === "A") {
        this.state.selectOption(0);
      } else if (key === "2" || key === "B") {
        this.state.selectOption(1);
      } else if (key === "3" || key === "C") {
        this.state.selectOption(2);
      } else if (key === "4" || key === "D") {
        this.state.selectOption(3);
      } else if (key === "N" || e.key === "ArrowRight") {
        this.state.next();
      } else if (key === "P" || e.key === "ArrowLeft") {
        this.state.prev();
      } else if (key === "M") {
        this.state.toggleMarkForReview();
      } else if (e.key === "Enter") {
        this.state.next();
      }
    };

    window.addEventListener("keydown", this.keydownHandler);
  }

  private renderFull() {
    const isFirst = this.state.currentIndex === 0;
    const isLast = this.state.currentIndex === this.state.questions.length - 1;
    const isMarked = this.state.markedForReview.has(this.state.currentQuestion?.id || "");

    this.container.innerHTML = `
      <div class="cbt-container">
        <!-- Main Question Column -->
        <div class="glass-panel cbt-main-panel">
          <div id="cbt-question-container">
            ${renderQuestionCard(this.state)}
          </div>

          <div class="cbt-action-footer">
            <button class="cbt-btn-prev" id="cbt-prev-btn" ${isFirst ? "disabled style='opacity:0.4;cursor:not-allowed;'" : ""}>
              ← Previous (P)
            </button>

            <button class="cbt-btn-mark" id="cbt-mark-btn">
              ${isMarked ? "★ Marked for Review (M)" : "☆ Mark for Review (M)"}
            </button>

            <button class="btn-primary" id="cbt-next-btn" style="flex: initial; padding: 0.65rem 1.4rem;">
              ${isLast ? "Review (N)" : "Next Question (N) →"}
            </button>
          </div>
        </div>

        <!-- Side Navigation Column -->
        <div class="glass-panel cbt-side-panel">
          <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 1.25rem;">
            <div style="font-weight: 800; font-size: 1rem; color: var(--ink-max);">${this.title}</div>
            <div class="cbt-timer-box">
              <span>⏱️</span>
              <span id="cbt-timer-display">${this.formatTime(this.state.timerSeconds)}</span>
            </div>
          </div>

          <div id="cbt-palette-container" style="flex: 1;">
            ${renderPaletteGrid(this.state)}
          </div>

          <div style="margin-top: 1.5rem; display: flex; flex-direction: column; gap: 0.65rem;">
            <button class="btn-primary" id="cbt-submit-test-btn" style="background: linear-gradient(135deg, var(--tulip-bloom-9), var(--tulip-plum-9));">
              <span>🏁 Submit Test</span>
            </button>
            <button class="btn-secondary" id="cbt-exit-btn">
              <span>Exit to Lobby</span>
            </button>
          </div>
        </div>
      </div>

      <!-- Result Modal Placeholder -->
      <div id="cbt-modal-container"></div>
    `;

    this.bindEvents();
    if (this.state.isSubmitted) {
      this.showResultsModal();
    }
  }

  private updateUI() {
    const qContainer = document.getElementById("cbt-question-container");
    if (qContainer) {
      qContainer.innerHTML = renderQuestionCard(this.state);
      this.bindQuestionCardEvents();
    }

    const pContainer = document.getElementById("cbt-palette-container");
    if (pContainer) {
      pContainer.innerHTML = renderPaletteGrid(this.state);
      this.bindPaletteClicks();
    }

    const prevBtn = document.getElementById("cbt-prev-btn") as HTMLButtonElement;
    if (prevBtn) {
      const isFirst = this.state.currentIndex === 0;
      prevBtn.disabled = isFirst;
      prevBtn.style.opacity = isFirst ? "0.4" : "1";
    }

    const markBtn = document.getElementById("cbt-mark-btn");
    if (markBtn) {
      const isMarked = this.state.markedForReview.has(this.state.currentQuestion?.id || "");
      markBtn.textContent = isMarked ? "★ Marked for Review (M)" : "☆ Mark for Review (M)";
    }

    if (this.state.isSubmitted) {
      this.showResultsModal();
    }
  }

  private bindEvents() {
    this.bindQuestionCardEvents();
    this.bindPaletteClicks();

    document.getElementById("cbt-prev-btn")?.addEventListener("click", () => this.state.prev());
    document.getElementById("cbt-next-btn")?.addEventListener("click", () => this.state.next());
    document.getElementById("cbt-mark-btn")?.addEventListener("click", () => this.state.toggleMarkForReview());

    document.getElementById("cbt-submit-test-btn")?.addEventListener("click", () => {
      if (confirm("Are you sure you want to finish and submit this test?")) {
        this.state.submit();
      }
    });

    document.getElementById("cbt-exit-btn")?.addEventListener("click", () => {
      if (confirm("Return to lobby? Your progress for this session will end.")) {
        this.destroy();
        this.onExit();
      }
    });
  }

  private bindQuestionCardEvents() {
    this.bindOptionClicks();
    document.getElementById("cbt-flag-btn")?.addEventListener("click", () => {
      this.showReportModal();
    });
  }

  private showReportModal() {
    const q = this.state.currentQuestion;
    if (!q) return;

    const modalContainer = document.getElementById("cbt-modal-container");
    if (!modalContainer) return;

    const reasons = [
      "Wrong answer key",
      "Question text typo / unclear",
      "Option text typo",
      "Solution wrong / incomplete",
      "Diagram missing or unclear",
      "Other",
    ];

    let selectedReason = reasons[0];

    modalContainer.innerHTML = `
      <div class="report-modal-overlay" id="report-modal-overlay">
        <div class="glass-card" style="max-width: 490px; width: 100%; padding: 2rem; border-color: var(--tulip-bloom-7);">
          <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 1rem;">
            <div>
              <h3 style="font-size: 1.35rem; font-weight: 800; color: var(--ink-max); margin: 0 0 0.25rem 0;">🚩 Report an Issue</h3>
              <div style="font-size: 0.82rem; font-weight: 600; color: var(--neutral-11);">${q.id} · ${q.exam} ${q.subject} (${q.year || "PYQ"})</div>
            </div>
            <button id="report-close-x" style="background: transparent; border: none; font-size: 1.25rem; color: var(--neutral-11); cursor: pointer;" title="Close">✕</button>
          </div>

          <p style="font-size: 0.88rem; color: var(--neutral-11); margin-bottom: 1rem; line-height: 1.45;">
            We log every report and verify it for upcoming builds. Pick a reason and send to our academic engineering desk:
          </p>

          <div class="report-reason-grid" id="report-reasons-list">
            ${reasons
              .map(
                (r, i) => `
              <div class="report-reason-option ${i === 0 ? "selected" : ""}" data-reason="${r}">
                <span class="report-radio-dot" style="font-size: 0.85rem; color: var(--tulip-bloom-9); font-weight: 700;">${i === 0 ? "●" : "○"}</span>
                <span>${r}</span>
              </div>
            `
              )
              .join("")}
          </div>

          <textarea id="report-user-note" class="report-textarea" placeholder="Your note (optional): e.g. diagram unavailable, second option text incomplete..."></textarea>

          <div style="display: flex; flex-direction: column; gap: 0.65rem;">
            <button class="btn-primary" id="report-send-email-btn">
              <span>✉️ Send Report via Email</span>
            </button>
            <div style="display: flex; gap: 0.5rem;">
              <button class="btn-secondary" id="report-copy-btn" style="flex: 1;">
                <span>📋 Copy Details</span>
              </button>
              <button class="btn-secondary" id="report-cancel-btn">
                <span>Cancel</span>
              </button>
            </div>
          </div>
        </div>
      </div>
    `;

    const reasonEls = modalContainer.querySelectorAll(".report-reason-option");
    reasonEls.forEach((el) => {
      el.addEventListener("click", () => {
        reasonEls.forEach((r) => {
          r.classList.remove("selected");
          const dot = r.querySelector(".report-radio-dot");
          if (dot) dot.textContent = "○";
        });
        el.classList.add("selected");
        const dot = el.querySelector(".report-radio-dot");
        if (dot) dot.textContent = "●";
        selectedReason = el.getAttribute("data-reason") || reasons[0];
      });
    });

    const closeModal = () => {
      modalContainer.innerHTML = "";
    };

    document.getElementById("report-close-x")?.addEventListener("click", closeModal);
    document.getElementById("report-cancel-btn")?.addEventListener("click", closeModal);

    document.getElementById("report-send-email-btn")?.addEventListener("click", () => {
      const note = (document.getElementById("report-user-note") as HTMLTextAreaElement)?.value || "";
      const bodyText = `Question ID: ${q.id}\nExam: ${q.exam}\nSubject: ${q.subject}\nYear: ${q.year || ""}\nReported reason: ${selectedReason}\n\nYour note (optional):\n${note}\n`;
      const subjectText = `QuestionX report: ${q.id}`;
      const mailtoUrl = `mailto:jai@altrusian.com?subject=${encodeURIComponent(subjectText)}&body=${encodeURIComponent(bodyText)}`;
      window.open(mailtoUrl, "_blank");
      alert(`Report logged for ${q.id}. Opening mail client...`);
      closeModal();
    });

    document.getElementById("report-copy-btn")?.addEventListener("click", () => {
      const note = (document.getElementById("report-user-note") as HTMLTextAreaElement)?.value || "";
      const bodyText = `Question ID: ${q.id}\nExam: ${q.exam}\nSubject: ${q.subject}\nYear: ${q.year || ""}\nReported reason: ${selectedReason}\n\nYour note (optional):\n${note}\n`;
      navigator.clipboard.writeText(bodyText).then(() => {
        alert("Report details copied to clipboard!");
      });
    });
  }

  private bindOptionClicks() {
    this.container.querySelectorAll(".cbt-option-item").forEach((el) => {
      el.addEventListener("click", (e) => {
        const target = e.currentTarget as HTMLElement;
        const optIndex = parseInt(target.getAttribute("data-option-index") || "0", 10);
        this.state.selectOption(optIndex);
      });
    });
  }

  private bindPaletteClicks() {
    this.container.querySelectorAll("[data-goto-index]").forEach((el) => {
      el.addEventListener("click", (e) => {
        const target = e.currentTarget as HTMLElement;
        const idx = parseInt(target.getAttribute("data-goto-index") || "0", 10);
        this.state.goTo(idx);
      });
    });
  }

  private showResultsModal() {
    const modalContainer = document.getElementById("cbt-modal-container");
    if (!modalContainer) return;

    blossom.burst(100);
    const summary = this.state.getSummary();

    modalContainer.innerHTML = `
      <div style="position: fixed; inset: 0; background: rgba(0,0,0,0.7); backdrop-filter: blur(12px); display: flex; align-items: center; justify-content: center; z-index: 100; padding: 1.5rem;">
        <div class="glass-card" style="max-width: 520px; width: 100%; padding: 2.25rem; text-align: center; border-color: var(--tulip-bloom-7);">
          <div style="font-size: 2.5rem; margin-bottom: 0.5rem;">🌸</div>
          <h2 style="font-size: 1.85rem; font-weight: 850; color: var(--ink-max); margin-bottom: 0.5rem;">Test Complete!</h2>
          <p style="color: var(--neutral-11); margin-bottom: 1.75rem;">Great work staying focused. Here is your official CBT breakdown:</p>

          <div style="display: grid; grid-template-columns: repeat(3, 1fr); gap: 1rem; margin-bottom: 1.75rem;">
            <div style="background: var(--ok-3); border: 1px solid var(--ok-6); padding: 1rem; border-radius: 12px;">
              <div style="font-size: 1.5rem; font-weight: 800; color: var(--ok-11);">${summary.correct}</div>
              <div style="font-size: 0.75rem; font-weight: 700; color: var(--ok-11);">Correct (+${summary.correct * 4})</div>
            </div>
            <div style="background: var(--danger-3); border: 1px solid var(--danger-6); padding: 1rem; border-radius: 12px;">
              <div style="font-size: 1.5rem; font-weight: 800; color: var(--danger-11);">${summary.incorrect}</div>
              <div style="font-size: 0.75rem; font-weight: 700; color: var(--danger-11);">Incorrect (-${summary.incorrect})</div>
            </div>
            <div style="background: var(--tulip-stem-3); border: 1px solid var(--tulip-stem-6); padding: 1rem; border-radius: 12px;">
              <div style="font-size: 1.5rem; font-weight: 800; color: var(--tulip-stem-11);">${Math.round(summary.accuracy)}%</div>
              <div style="font-size: 0.75rem; font-weight: 700; color: var(--tulip-stem-11);">Accuracy</div>
            </div>
          </div>

          <div style="background: light-dark(var(--neutral-3), rgba(255,255,255,0.06)); padding: 1rem; border-radius: 12px; margin-bottom: 2rem;">
            <div style="font-size: 0.85rem; color: var(--neutral-11); margin-bottom: 0.25rem;">Final Score</div>
            <div style="font-size: 2rem; font-weight: 850; color: var(--tulip-bloom-10);">${summary.score} <span style="font-size: 1rem; color: var(--neutral-11);">/ ${summary.maxScore}</span></div>
          </div>

          <div style="display: flex; gap: 0.75rem;">
            <button class="btn-primary" id="modal-review-btn">
              <span>📖 Review Solutions</span>
            </button>
            <button class="btn-secondary" id="modal-lobby-btn">
              <span>Back to Lobby</span>
            </button>
          </div>
        </div>
      </div>
    `;

    document.getElementById("modal-review-btn")?.addEventListener("click", () => {
      modalContainer.innerHTML = "";
    });

    document.getElementById("modal-lobby-btn")?.addEventListener("click", () => {
      this.destroy();
      this.onExit();
    });
  }
}
