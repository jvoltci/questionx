import "./styles/app.css";
import { listenTulipUnlock, unlockTulip } from "nilam/tulip";
import { LobbyView } from "./views/LobbyView";
import { ExamView } from "./views/ExamView";
import { QuizState } from "./state/quizState";
import { blossom } from "./effects/blossom";

class PadhaiApp {
  private appContainer: HTMLElement;
  private currentExamView: ExamView | null = null;
  private currentLobbyView: LobbyView | null = null;
  private streakContainer: HTMLElement | null = null;
  private streakLabel: HTMLElement | null = null;

  constructor() {
    this.appContainer = document.getElementById("app") as HTMLElement;
    this.streakContainer = document.getElementById("streak-container");
    this.streakLabel = document.getElementById("streak-label");

    this.initTheme();
    this.initTulipVault();
    this.initFeedback();
    this.initBrandLink();
    this.showLobby();
  }

  private initTheme() {
    const root = document.documentElement;
    const themeBtn = document.getElementById("theme-toggle");
    const themeIcon = document.getElementById("theme-icon");

    // Load saved or system preference
    const savedTheme = localStorage.getItem("padhai_theme");
    const prefersDark = window.matchMedia("(prefers-color-scheme: dark)").matches;
    const isDark = savedTheme ? savedTheme === "dark" : prefersDark;

    root.classList.toggle("dark", isDark);
    root.classList.toggle("light", !isDark);
    if (themeIcon) themeIcon.textContent = isDark ? "☀️" : "🌙";

    themeBtn?.addEventListener("click", () => {
      const nowDark = !root.classList.contains("dark");
      root.classList.toggle("dark", nowDark);
      root.classList.toggle("light", !nowDark);
      if (themeIcon) themeIcon.textContent = nowDark ? "☀️" : "🌙";
      localStorage.setItem("padhai_theme", nowDark ? "dark" : "light");
    });
  }

  private initTulipVault() {
    // Activate Tulip Vault classes on root
    unlockTulip();

    // Listen for secret activation order ('t'-'u'-'l'-'i'-'p')
    listenTulipUnlock();

    window.addEventListener("nilam:tulip:unlocked", () => {
      blossom.burst(90);
    });
  }

  private initBrandLink() {
    document.getElementById("brand-link")?.addEventListener("click", (e) => {
      e.preventDefault();
      if (this.currentExamView) {
        if (confirm("Return to home screen? Current test session will end.")) {
          this.currentExamView.destroy();
          this.showLobby();
        }
      } else {
        this.showLobby();
      }
    });
  }

  private initFeedback() {
    const feedbackBtn = document.getElementById("feedback-btn");
    const container = document.getElementById("feedback-modal-container");
    if (!feedbackBtn || !container) return;

    feedbackBtn.addEventListener("click", () => {
      container.innerHTML = `
        <div class="report-modal-overlay" id="feedback-modal-overlay">
          <div class="glass-card" style="max-width: 480px; width: 100%; padding: 2rem; border-color: var(--tulip-bloom-7);">
            <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 1rem;">
              <div>
                <h3 style="font-size: 1.35rem; font-weight: 850; color: var(--ink-max); margin: 0 0 0.25rem 0;">💬 Contact & Feedback</h3>
                <div style="font-size: 0.82rem; font-weight: 600; color: var(--neutral-11);">Padhai Web Client · Student Support</div>
              </div>
              <button id="feedback-close-x" style="background: transparent; border: none; font-size: 1.25rem; color: var(--neutral-11); cursor: pointer;" title="Close">✕</button>
            </div>

            <p style="font-size: 0.88rem; color: var(--neutral-11); margin-bottom: 1rem; line-height: 1.45;">
              We read and act on all student feedback! Send feature requests, suggestions, or issues directly to our developer team:
            </p>

            <textarea id="feedback-text" class="report-textarea" placeholder="Tell us how we can make Padhai even better for computer/laptop users..."></textarea>

            <div style="display: flex; flex-direction: column; gap: 0.65rem;">
              <button class="btn-primary" id="feedback-send-email-btn">
                <span>✉️ Send Feedback Email</span>
              </button>
              <div style="display: flex; gap: 0.5rem;">
                <button class="btn-secondary" id="feedback-copy-email-btn" style="flex: 1;">
                  <span>📋 Copy Email Address</span>
                </button>
                <button class="btn-secondary" id="feedback-cancel-btn">
                  <span>Cancel</span>
                </button>
              </div>
            </div>
          </div>
        </div>
      `;

      const closeModal = () => {
        container.innerHTML = "";
      };

      document.getElementById("feedback-close-x")?.addEventListener("click", closeModal);
      document.getElementById("feedback-cancel-btn")?.addEventListener("click", closeModal);

      document.getElementById("feedback-send-email-btn")?.addEventListener("click", () => {
        const text = (document.getElementById("feedback-text") as HTMLTextAreaElement)?.value || "";
        const subject = encodeURIComponent("QuestionX Feedback — Padhai Web");
        const body = encodeURIComponent(text);
        window.open(`mailto:j.voltci@gmail.com?subject=${subject}&body=${body}`, "_blank");
        alert("Thank you for your feedback! Opening mail app...");
        closeModal();
      });

      document.getElementById("feedback-copy-email-btn")?.addEventListener("click", () => {
        navigator.clipboard.writeText("j.voltci@gmail.com").then(() => {
          alert("Developer email (j.voltci@gmail.com) copied to clipboard!");
        });
      });
    });
  }

  private showLobby() {
    if (this.currentExamView) {
      this.currentExamView.destroy();
      this.currentExamView = null;
    }

    if (this.streakContainer) {
      this.streakContainer.style.display = "none";
    }

    this.currentLobbyView = new LobbyView(this.appContainer, (state, title) => {
      this.showExam(state, title);
    });

    this.currentLobbyView.render();
  }

  private showExam(state: QuizState, title: string) {
    if (this.streakContainer && this.streakLabel) {
      this.streakContainer.style.display = "inline-flex";
      this.streakLabel.textContent = `${state.currentStreak} Streak`;

      state.subscribe(() => {
        if (this.streakLabel) {
          this.streakLabel.textContent = `${state.currentStreak} Streak`;
        }
      });
    }

    this.currentExamView = new ExamView(this.appContainer, state, title, () => {
      this.showLobby();
    });

    this.currentExamView.render();
  }
}

// Initialize on DOM ready
if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", () => new PadhaiApp());
} else {
  new PadhaiApp();
}
