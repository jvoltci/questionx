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
