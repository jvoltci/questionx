import { QuestionRecord } from "../crypto/crypto";
import { blossom } from "../effects/blossom";
import { telemetry } from "../telemetry/tracker";

export type QuestionStatus = "answered" | "unanswered" | "notvisited" | "review";

export interface QuizSummary {
  correct: number;
  incorrect: number;
  unattempted: number;
  total: number;
  score: number;
  maxScore: number;
  accuracy: number;
}

export class QuizState {
  questions: QuestionRecord[] = [];
  currentIndex: number = 0;
  answers: Map<string, number> = new Map(); // questionId -> option index (0..3)
  markedForReview: Set<string> = new Set();
  visited: Set<string> = new Set();
  timerSeconds: number = 0;
  isSubmitted: boolean = false;
  listeners: Array<() => void> = [];

  // Streak tracking
  currentStreak: number = 0;
  bestStreak: number = 0;
  totalAnswered: number = 0;

  questionStartTime: number = Date.now();
  questionDwellTimes: Map<string, number> = new Map();

  constructor(questions: QuestionRecord[], durationMinutes: number = 45) {
    this.questions = questions;
    this.timerSeconds = durationMinutes * 60;
    this.questionStartTime = Date.now();
    if (questions.length > 0) {
      this.visited.add(questions[0].id);
    }
  }

  subscribe(listener: () => void) {
    this.listeners.push(listener);
    return () => {
      this.listeners = this.listeners.filter((l) => l !== listener);
    };
  }

  notify() {
    for (const listener of this.listeners) {
      listener();
    }
  }

  get currentQuestion(): QuestionRecord | undefined {
    return this.questions[this.currentIndex];
  }

  getStatus(questionId: string): QuestionStatus {
    const isAnswered = this.answers.has(questionId);
    const isReview = this.markedForReview.has(questionId);
    const isVisited = this.visited.has(questionId);

    if (isReview) return "review";
    if (isAnswered) return "answered";
    if (isVisited) return "unanswered";
    return "notvisited";
  }

  selectOption(optionIndex: number) {
    if (this.isSubmitted || !this.currentQuestion) return;
    const q = this.currentQuestion;
    const isNewAnswer = !this.answers.has(q.id);
    this.answers.set(q.id, optionIndex);

    const elapsed = Math.max(1, Math.round((Date.now() - this.questionStartTime) / 1000));
    const priorDwell = this.questionDwellTimes.get(q.id) || 0;
    const totalDwell = priorDwell + elapsed;
    this.questionDwellTimes.set(q.id, totalDwell);

    const correctLetter = q.answer_key ? q.answer_key.trim().toUpperCase() : "";
    const selectedLetter = String.fromCharCode(65 + optionIndex);
    const isCorrect = correctLetter ? selectedLetter === correctLetter : false;

    if (isNewAnswer) {
      this.totalAnswered++;
      if (isCorrect) {
        this.currentStreak++;
        if (this.currentStreak > this.bestStreak) {
          this.bestStreak = this.currentStreak;
        }
        if (this.currentStreak % 5 === 0) {
          blossom.burst(40);
          try {
            telemetry.track('streak_milestone', {
              streak: this.currentStreak,
              subject: q.subject,
            });
          } catch {}
        }
      } else {
        this.currentStreak = 0;
      }
    }

    try {
      telemetry.track('question_answered', {
        question_id: q.id,
        subject: q.subject,
        exam: q.exam,
        dwell_seconds: totalDwell,
        is_correct: isCorrect,
        is_new_answer: isNewAnswer,
        streak_at_answer: this.currentStreak,
      });
    } catch {}

    this.notify();
  }

  clearResponse() {
    if (this.isSubmitted || !this.currentQuestion) return;
    if (this.answers.has(this.currentQuestion.id)) {
      this.totalAnswered = Math.max(0, this.totalAnswered - 1);
    }
    this.answers.delete(this.currentQuestion.id);
    this.notify();
  }

  toggleMarkForReview() {
    if (!this.currentQuestion) return;
    const id = this.currentQuestion.id;
    if (this.markedForReview.has(id)) {
      this.markedForReview.delete(id);
    } else {
      this.markedForReview.add(id);
    }
    this.notify();
  }

  goTo(index: number) {
    if (index >= 0 && index < this.questions.length) {
      if (this.currentQuestion) {
        const elapsed = Math.max(1, Math.round((Date.now() - this.questionStartTime) / 1000));
        const priorDwell = this.questionDwellTimes.get(this.currentQuestion.id) || 0;
        this.questionDwellTimes.set(this.currentQuestion.id, priorDwell + elapsed);
      }
      this.currentIndex = index;
      this.questionStartTime = Date.now();
      this.visited.add(this.questions[index].id);
      this.notify();
    }
  }

  next() {
    if (this.currentIndex < this.questions.length - 1) {
      this.goTo(this.currentIndex + 1);
    }
  }

  prev() {
    if (this.currentIndex > 0) {
      this.goTo(this.currentIndex - 1);
    }
  }

  submit() {
    this.isSubmitted = true;
    blossom.burst(100);
    const summary = this.getSummary();
    const answeredCount = summary.correct + summary.incorrect;

    let totalDwell = 0;
    for (const d of this.questionDwellTimes.values()) totalDwell += d;
    const avgDwell = answeredCount > 0 ? Math.round(totalDwell / answeredCount) : 0;

    try {
      telemetry.track('quiz_completed', {
        total_questions: summary.total,
        answered: answeredCount,
        correct: summary.correct,
        incorrect: summary.incorrect,
        score: summary.score,
        accuracy_percent: Math.round(summary.accuracy),
        best_streak: this.bestStreak,
        avg_dwell_seconds: avgDwell,
        subject: this.questions[0]?.subject || 'Mixed',
        exam: this.questions[0]?.exam || 'General',
      });
    } catch {}
    this.notify();
  }

  getSummary(): QuizSummary {
    let correct = 0;
    let incorrect = 0;
    let unattempted = 0;

    for (const q of this.questions) {
      const selected = this.answers.get(q.id);
      if (selected === undefined) {
        unattempted++;
      } else {
        const correctLetter = q.answer_key?.trim().toUpperCase();
        const selectedLetter = String.fromCharCode(65 + selected);
        if (selectedLetter === correctLetter) {
          correct++;
        } else {
          incorrect++;
        }
      }
    }

    const total = this.questions.length;
    // Standard NEET/JEE scoring: +4 for correct, -1 for incorrect, 0 for unattempted
    const score = correct * 4 - incorrect;
    const maxScore = total * 4;
    const accuracy = correct + incorrect > 0 ? (correct / (correct + incorrect)) * 100 : 0;

    return { correct, incorrect, unattempted, total, score, maxScore, accuracy };
  }
}
