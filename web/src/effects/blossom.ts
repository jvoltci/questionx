/**
 * Wisteria Blossom Particle Engine for Padhai (TULIP Vault)
 * Lightweight canvas-based particle bursts for celebrations & secret vault unlock.
 */

interface Petal {
  x: number;
  y: number;
  size: number;
  speedX: number;
  speedY: number;
  angle: number;
  angularSpeed: number;
  color: string;
  opacity: number;
  decay: number;
  isSpark: boolean;
}

const WISTERIA_COLORS = [
  '#c084fc', // Bloom
  '#a855f7', // Vivid Violet
  '#818cf8', // Lavender Indigo
  '#e9d5ff', // Pale Wisteria
  '#fde047', // Buttercup Spark
  '#facc15', // Gold
];

class BlossomEngine {
  private canvas: HTMLCanvasElement | null = null;
  private ctx: CanvasRenderingContext2D | null = null;
  private petals: Petal[] = [];
  private isRunning = false;
  private animFrameId: number | null = null;

  public stop() {
    if (this.animFrameId) {
      cancelAnimationFrame(this.animFrameId);
      this.animFrameId = null;
    }
    this.isRunning = false;
  }

  constructor() {
    this.init();
  }

  private init() {
    if (typeof window === 'undefined') return;
    this.canvas = document.getElementById('blossom-canvas') as HTMLCanvasElement;
    if (!this.canvas) return;

    this.ctx = this.canvas.getContext('2d');
    this.resize();
    window.addEventListener('resize', () => this.resize());
  }

  private resize() {
    if (!this.canvas) return;
    this.canvas.width = window.innerWidth;
    this.canvas.height = window.innerHeight;
  }

  public burst(count = 70, originX = window.innerWidth / 2, originY = window.innerHeight * 0.3) {
    if (!this.canvas) this.init();
    if (!this.ctx) return;

    for (let i = 0; i < count; i++) {
      const angle = Math.random() * Math.PI * 2;
      const speed = Math.random() * 8 + 3;
      const isSpark = Math.random() < 0.25;

      this.petals.push({
        x: originX + (Math.random() - 0.5) * 40,
        y: originY + (Math.random() - 0.5) * 40,
        size: isSpark ? Math.random() * 4 + 2 : Math.random() * 10 + 6,
        speedX: Math.cos(angle) * speed,
        speedY: Math.sin(angle) * speed - 3,
        angle: Math.random() * Math.PI * 2,
        angularSpeed: (Math.random() - 0.5) * 0.1,
        color: WISTERIA_COLORS[Math.floor(Math.random() * WISTERIA_COLORS.length)],
        opacity: 1,
        decay: Math.random() * 0.012 + 0.008,
        isSpark,
      });
    }

    if (!this.isRunning) {
      this.isRunning = true;
      this.loop();
    }
  }

  private loop = () => {
    if (!this.ctx || !this.canvas) return;

    this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);

    for (let i = this.petals.length - 1; i >= 0; i--) {
      const p = this.petals[i];
      p.x += p.speedX;
      p.y += p.speedY;
      p.speedY += 0.12; // Gravity
      p.speedX *= 0.98; // Air resistance
      p.angle += p.angularSpeed;
      p.opacity -= p.decay;

      if (p.opacity <= 0 || p.y > this.canvas.height + 50) {
        this.petals.splice(i, 1);
        continue;
      }

      this.ctx.save();
      this.ctx.globalAlpha = Math.max(0, p.opacity);
      this.ctx.translate(p.x, p.y);
      this.ctx.rotate(p.angle);
      this.ctx.fillStyle = p.color;

      if (p.isSpark) {
        // Star spark
        this.ctx.beginPath();
        this.ctx.arc(0, 0, p.size / 2, 0, Math.PI * 2);
        this.ctx.fill();
      } else {
        // Organic petal shape
        this.ctx.beginPath();
        this.ctx.ellipse(0, 0, p.size, p.size * 0.55, 0, 0, Math.PI * 2);
        this.ctx.fill();
      }

      this.ctx.restore();
    }

    if (this.petals.length > 0) {
      this.animFrameId = requestAnimationFrame(this.loop);
    } else {
      this.isRunning = false;
      this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
    }
  };
}

export const blossom = new BlossomEngine();
