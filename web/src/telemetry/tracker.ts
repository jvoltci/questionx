/**
 * First-Party Talent & Mastery Telemetry Engine for Padhai
 * Captures high-signal student problem-solving performance, streaks, and subject mastery.
 * Offline-resilient: buffers events locally and flushes silently when connected.
 */

export interface TelemetryEvent {
  event: string;
  student_id: string;
  session_id: string;
  timestamp: number;
  properties: Record<string, any>;
}

class TelemetryTracker {
  private studentId: string;
  private sessionId: string;
  private queue: TelemetryEvent[] = [];
  private flushTimer: any = null;

  constructor(appSource: string) {
    this.studentId = this.getOrCreateStudentId();
    this.sessionId = 'sess_' + Math.random().toString(36).substring(2, 10);
    this.loadQueue();

    window.addEventListener('online', () => this.flush());
    window.addEventListener('pagehide', () => this.flush());
    document.addEventListener('visibilitychange', () => {
      if (document.visibilityState === 'hidden') this.flush();
    });

    this.track('session_start', {
      app: appSource,
      referrer: document.referrer || 'direct',
      screen_width: window.innerWidth,
      screen_height: window.innerHeight,
    });
  }

  private getOrCreateStudentId(): string {
    let id = localStorage.getItem('altrusian_student_id');
    if (!id) {
      id = 'stu_' + Math.random().toString(36).substring(2, 12) + Date.now().toString(36);
      localStorage.setItem('altrusian_student_id', id);
    }
    return id;
  }

  track(event: string, properties: Record<string, any> = {}) {
    const payload: TelemetryEvent = {
      event,
      student_id: this.studentId,
      session_id: this.sessionId,
      timestamp: Date.now(),
      properties,
    };

    this.queue.push(payload);
    this.saveQueue();

    if (navigator.onLine && !this.flushTimer) {
      this.flushTimer = setTimeout(() => this.flush(), 2000);
    }
  }

  private saveQueue() {
    try {
      localStorage.setItem('altrusian_telemetry_queue', JSON.stringify(this.queue.slice(-50)));
    } catch {}
  }

  private loadQueue() {
    try {
      const saved = localStorage.getItem('altrusian_telemetry_queue');
      if (saved) {
        this.queue = JSON.parse(saved);
      }
    } catch {}
  }

  flush() {
    if (this.flushTimer) {
      clearTimeout(this.flushTimer);
      this.flushTimer = null;
    }

    if (this.queue.length === 0 || !navigator.onLine) return;

    const eventsToSend = [...this.queue];
    const body = JSON.stringify({
      student_id: this.studentId,
      events: eventsToSend,
    });

    if (navigator.sendBeacon) {
      const blob = new Blob([body], { type: 'application/json' });
      const sent = navigator.sendBeacon('/api/telemetry', blob);
      if (sent) {
        this.queue = [];
        this.saveQueue();
        return;
      }
    }

    fetch('/api/telemetry', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body,
      keepalive: true,
    })
      .then((res) => {
        if (res.ok) {
          this.queue = [];
          this.saveQueue();
        }
      })
      .catch(() => {});
  }
}

export const telemetry = new TelemetryTracker('padhai');
