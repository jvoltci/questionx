import { WebManifest, decryptChunk } from "../crypto/crypto";
import { QuizState } from "../state/quizState";

export class LobbyView {
  private container: HTMLElement;
  private manifest: WebManifest | null = null;
  private currentExam: "NEET" | "JEE" = "NEET";
  private onStartQuiz: (state: QuizState, title: string) => void;

  constructor(container: HTMLElement, onStartQuiz: (state: QuizState, title: string) => void) {
    this.container = container;
    this.onStartQuiz = onStartQuiz;
  }

  async render() {
    this.container.innerHTML = `
      <div style="display: flex; justify-content: center; align-items: center; min-height: 400px;">
        <div style="text-align: center;">
          <div style="font-size: 2rem; margin-bottom: 1rem; animation: streakGlow 1.5s infinite;">🌸</div>
          <div style="font-size: 1.1rem; font-weight: 700; color: var(--ink-max);">Loading Question Bank...</div>
        </div>
      </div>
    `;

    try {
      const res = await fetch("data/manifest.json");
      if (!res.ok) throw new Error("Manifest load failed");
      this.manifest = await res.json();
    } catch {
      this.manifest = {
        version: "1.0",
        generated_at: Date.now(),
        total_questions: 18642,
        chunks: [
          { id: "neet_bio", exam: "NEET", subject: "Biology", count: 7120, file: "neet_bio.bin.enc", size: 4500000, topics: ["Cell Biology", "Genetics", "Human Physiology"], years: [2010, 2024] },
          { id: "neet_chem", exam: "NEET", subject: "Chemistry", count: 3240, file: "neet_chem.bin.enc", size: 2800000, topics: ["Organic", "Inorganic", "Physical"], years: [2010, 2024] },
          { id: "neet_phy", exam: "NEET", subject: "Physics", count: 2890, file: "neet_phy.bin.enc", size: 2600000, topics: ["Mechanics", "Electrodynamics", "Optics"], years: [2010, 2024] },
          { id: "jee_math", exam: "JEE", subject: "Mathematics", count: 2150, file: "jee_math.bin.enc", size: 2200000, topics: ["Calculus", "Algebra", "Vectors & 3D"], years: [2015, 2026] },
          { id: "jee_phy", exam: "JEE", subject: "Physics", count: 1820, file: "jee_phy.bin.enc", size: 1900000, topics: ["Modern Physics", "Thermodynamics"], years: [2015, 2026] },
          { id: "jee_chem", exam: "JEE", subject: "Chemistry", count: 1422, file: "jee_chem.bin.enc", size: 1600000, topics: ["Coordination Compounds", "Electrochemistry"], years: [2015, 2026] },
        ],
      };
    }

    this.renderLobby();
  }

  private renderLobby() {
    if (!this.manifest) return;

    const filteredChunks = this.manifest.chunks.filter((c) => c.exam === this.currentExam);

    const subjectIcons: Record<string, string> = {
      Biology: "🧬",
      Chemistry: "🧪",
      Physics: "⚡",
      Mathematics: "📐",
    };

    const cardsHtml = filteredChunks
      .map((chunk) => {
        const icon = subjectIcons[chunk.subject] || "📚";
        return `
        <div class="glass-card lobby-subject-card">
          <div class="lobby-subject-header">
            <div class="lobby-subject-icon">${icon}</div>
            <span class="cbt-q-subject-badge">${chunk.exam}</span>
          </div>

          <div class="lobby-subject-title">${chunk.subject}</div>
          <div class="lobby-subject-stats">
            <span>📊 ${chunk.count.toLocaleString()} Verified Questions</span>
            <span>•</span>
            <span>${chunk.years[0]}–${chunk.years[chunk.years.length - 1]}</span>
          </div>

          <div style="font-size: 0.85rem; color: var(--neutral-11); margin-bottom: 1.5rem; line-height: 1.5;">
            High-yield past year questions with complete diagrams, official keys, and step-by-step verified solutions.
          </div>

          <div class="lobby-actions">
            <button class="btn-primary" data-chunk-file="${chunk.file}" data-mode="practice">
              <span>🎯 Practice Mode</span>
            </button>
            <button class="btn-secondary" data-chunk-file="${chunk.file}" data-mode="timed">
              <span>⏱️ Timed CBT</span>
            </button>
          </div>
        </div>
      `;
      })
      .join("");

    this.container.innerHTML = `
      <div class="lobby-hero">
        <div class="lobby-hero-badge">🌸 Nilam 2.0 TULIP Vault Active</div>
        <h1>Master NEET & JEE with <span>Blissful Focus</span></h1>
        <p>
          Offline-ready, self-contained computer-based testing with zero latency, verified step-by-step solutions, and tactile dopamine flow.
        </p>

        <div class="lobby-exam-toggle">
          <button class="lobby-toggle-btn ${this.currentExam === "NEET" ? "active" : ""}" data-exam="NEET">
            NEET UG (${this.manifest.chunks.filter((c) => c.exam === "NEET").reduce((a, b) => a + b.count, 0).toLocaleString()} Qs)
          </button>
          <button class="lobby-toggle-btn ${this.currentExam === "JEE" ? "active" : ""}" data-exam="JEE">
            JEE Main & Adv (${this.manifest.chunks.filter((c) => c.exam === "JEE").reduce((a, b) => a + b.count, 0).toLocaleString()} Qs)
          </button>
        </div>
      </div>

      <div class="lobby-grid">
        ${cardsHtml}
      </div>
    `;

    this.bindEvents();
  }

  private bindEvents() {
    // Exam toggle
    this.container.querySelectorAll(".lobby-toggle-btn").forEach((btn) => {
      btn.addEventListener("click", (e) => {
        const target = e.currentTarget as HTMLElement;
        const exam = target.getAttribute("data-exam") as "NEET" | "JEE";
        if (exam && exam !== this.currentExam) {
          this.currentExam = exam;
          this.renderLobby();
        }
      });
    });

    // Start practice/test
    this.container.querySelectorAll("[data-chunk-file]").forEach((btn) => {
      btn.addEventListener("click", async (e) => {
        const target = e.currentTarget as HTMLElement;
        const file = target.getAttribute("data-chunk-file");
        const mode = target.getAttribute("data-mode") as "practice" | "timed";
        if (!file) return;

        target.textContent = "⏳ Decrypting...";
        (target as HTMLButtonElement).disabled = true;

        try {
          const res = await fetch(`data/${file}`);
          if (!res.ok) throw new Error("Failed to download encrypted chunk");
          const buffer = await res.arrayBuffer();
          const questions = await decryptChunk(buffer);

          // Shuffle for practice or take set
          const shuffled = [...questions].sort(() => Math.random() - 0.5);
          const testQuestions = mode === "timed" ? shuffled.slice(0, 45) : shuffled.slice(0, 60);

          const subjectTitle = file.replace(/\.bin\.enc$/, "").replace(/_/g, " ").toUpperCase();
          const duration = mode === "timed" ? 45 : 90;
          const quizState = new QuizState(testQuestions, duration);
          this.onStartQuiz(quizState, subjectTitle);
        } catch (err) {
          alert("Error loading questions: " + err);
          target.textContent = "Try Again";
          (target as HTMLButtonElement).disabled = false;
        }
      });
    });
  }
}
