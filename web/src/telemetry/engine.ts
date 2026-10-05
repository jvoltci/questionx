/**
 * Cloudflare Worker Telemetry Engine
 * Processes student events, evaluates cognitive archetypes, and manages candidate scouting state in KV.
 */

export interface KVNamespaceLike {
  get: (key: string, type?: string) => Promise<any>;
  put: (key: string, value: string) => Promise<void>;
}

export interface StudentProfile {
  student_id: string;
  app: string;
  location: string;
  first_seen: number;
  last_seen: number;
  total_events: number;
  questions_attempted: number;
  correct_answers: number;
  best_streak: number;
  current_streak: number;
  total_dwell_seconds: number;
  dwell_count: number;
  avg_dwell_seconds: number;
  derivations_viewed: number;
  latex_copies: number;
  searches_count: number;
  duels_played?: number;
  duels_won?: number;
  checkins_count?: number;
  archetype: string;
  scout_score: number;
  candidate_status: string;
  notes?: string;
}

export function evaluateStudent(s: StudentProfile): void {
  const accuracy = s.questions_attempted > 0 ? (s.correct_answers / s.questions_attempted) * 100 : 0;
  const avgDwell = s.dwell_count > 0 ? Math.round(s.total_dwell_seconds / s.dwell_count) : s.avg_dwell_seconds;
  s.avg_dwell_seconds = avgDwell;

  if (s.questions_attempted >= 3) {
    if (accuracy >= 80 && avgDwell >= 35 && avgDwell <= 120) {
      s.archetype = 'Deep Thinker';
    } else if (accuracy >= 70 && avgDwell >= 25) {
      s.archetype = 'Methodical Solver';
    } else if (s.questions_attempted >= 8 && accuracy < 50 && avgDwell < 20) {
      s.archetype = 'Rote Churner';
    } else if (s.questions_attempted >= 5 && accuracy < 40 && avgDwell < 15) {
      s.archetype = 'Quick Guesser';
    } else {
      s.archetype = 'Explorer';
    }
  } else if (s.derivations_viewed >= 2) {
    s.archetype = 'Deep Thinker';
  } else {
    s.archetype = 'Explorer';
  }

  // Scouting score: 0 to 100
  const accScore = Math.min(35, (accuracy / 100) * 35);
  let dwellScore = 0;
  if (avgDwell >= 35 && avgDwell <= 120) {
    dwellScore = 30;
  } else if (avgDwell >= 20) {
    dwellScore = 20;
  } else if (avgDwell > 0) {
    dwellScore = 10;
  }
  const derivScore = Math.min(20, s.derivations_viewed * 10);
  const streakScore = Math.min(15, s.best_streak * 3);

  s.scout_score = Math.round(accScore + dwellScore + derivScore + streakScore);

  if (s.scout_score >= 78) {
    s.candidate_status = 'Top Talent';
  } else if (s.scout_score >= 60) {
    s.candidate_status = 'Strong Potential';
  } else if (s.scout_score >= 40) {
    s.candidate_status = 'Developing';
  } else {
    s.candidate_status = 'Standard';
  }
}

export async function processTelemetry(
  kv: KVNamespaceLike | undefined,
  payload: any,
  ip: string,
  city: string,
  country: string
): Promise<void> {
  if (!kv) return;

  const now = Date.now();
  const location = city && country ? `${city}, ${country}` : (country || (ip ? `IP: ${ip}` : 'India'));
  const studentId = payload.student_id || 'anon_student';

  // Load or initialize student profile
  let student: StudentProfile | null = await kv.get(`student:${studentId}`, 'json');
  if (!student) {
    student = {
      student_id: studentId,
      app: payload.app || 'padhai',
      location,
      first_seen: now,
      last_seen: now,
      total_events: 0,
      questions_attempted: 0,
      correct_answers: 0,
      best_streak: 0,
      current_streak: 0,
      total_dwell_seconds: 0,
      dwell_count: 0,
      avg_dwell_seconds: 0,
      derivations_viewed: 0,
      latex_copies: 0,
      searches_count: 0,
      archetype: 'Explorer',
      scout_score: 0,
      candidate_status: 'Standard',
    };
  }

  const events: any[] = Array.isArray(payload.events) ? payload.events : [payload];
  const newEventsToStore: any[] = [];

  for (const raw of events) {
    student.total_events++;
    student.last_seen = now;
    if (location && location !== 'Unknown') student.location = location;
    if (raw.app) student.app = raw.app;

    const evtName = raw.event || 'action';
    const props = raw.properties || {};

    if (evtName === 'question_answered') {
      if (props.is_new_answer !== false) {
        student.questions_attempted++;
        if (props.is_correct) student.correct_answers++;
      }
      if (props.dwell_seconds) {
        student.total_dwell_seconds += Number(props.dwell_seconds);
        student.dwell_count++;
      }
      if (props.streak_at_answer) {
        student.current_streak = props.streak_at_answer;
        if (props.streak_at_answer > student.best_streak) {
          student.best_streak = props.streak_at_answer;
        }
      }
    } else if (evtName === 'quiz_completed') {
      if (props.correct) student.correct_answers = Math.max(student.correct_answers, props.correct);
      if (props.answered) student.questions_attempted = Math.max(student.questions_attempted, props.answered);
      if (props.best_streak) student.best_streak = Math.max(student.best_streak, props.best_streak);
      if (props.avg_dwell_seconds && student.dwell_count === 0) {
        student.total_dwell_seconds = props.avg_dwell_seconds * (props.answered || 1);
        student.dwell_count = props.answered || 1;
      }
    } else if (evtName === 'derivation_expanded') {
      student.derivations_viewed++;
    } else if (evtName === 'latex_copied') {
      student.latex_copies++;
    } else if (evtName === 'formula_searched') {
      student.searches_count++;
    } else if (evtName === 'streak_milestone') {
      if (props.streak && props.streak > student.best_streak) {
        student.best_streak = props.streak;
      }
    } else if (evtName === 'duel_completed') {
      student.duels_played = (student.duels_played || 0) + 1;
      if (props.won) {
        student.duels_won = (student.duels_won || 0) + 1;
      }
    } else if (evtName === 'checkin_completed' || evtName === 'seat_booked') {
      student.checkins_count = (student.checkins_count || 0) + 1;
      if (student.archetype === 'Explorer') {
        student.archetype = 'Consistent Scholar';
      }
    }

    evaluateStudent(student);

    newEventsToStore.push({
      id: 'evt_' + Math.random().toString(36).substring(2, 9),
      timestamp: raw.timestamp || now,
      event: evtName,
      student_id: studentId,
      session_id: raw.session_id || 'session',
      location: student.location,
      app: student.app,
      archetype: student.archetype,
      scout_score: student.scout_score,
      properties: props,
    });
  }

  // Save student profile
  await kv.put(`student:${studentId}`, JSON.stringify(student));

  // Update recent events ring buffer
  try {
    const existingEvents: any[] = (await kv.get('recent_events', 'json')) || [];
    const merged = [...newEventsToStore, ...existingEvents].slice(0, 100);
    await kv.put('recent_events', JSON.stringify(merged));
  } catch {}

  // Update candidate roster if high signal
  if (student.scout_score >= 60) {
    try {
      const roster: StudentProfile[] = (await kv.get('roster', 'json')) || [];
      const filtered = roster.filter((c) => c.student_id !== student!.student_id);
      filtered.push(student);
      filtered.sort((a, b) => b.scout_score - a.scout_score);
      await kv.put('roster', JSON.stringify(filtered.slice(0, 30)));
    } catch {}
  }

  // Update summary counts
  try {
    let summary: any = await kv.get('summary', 'json');
    if (!summary) {
      summary = {
        active_students: 1,
        total_students_tracked: 1,
        studious_ratio: 75,
        total_questions: 0,
        total_derivations: 0,
        total_duels: 0,
        total_checkins: 0,
        scouted_candidates: 0,
      };
    }
    summary.total_questions = (summary.total_questions || 0) + (events.filter((e) => e.event === 'question_answered').length);
    summary.total_derivations = (summary.total_derivations || 0) + (events.filter((e) => e.event === 'derivation_expanded').length);
    summary.total_duels = (summary.total_duels || 0) + (events.filter((e) => e.event === 'duel_completed').length);
    summary.total_checkins = (summary.total_checkins || 0) + (events.filter((e) => e.event === 'checkin_completed' || e.event === 'seat_booked').length);

    // Save roster count to summary
    const roster: any[] = (await kv.get('roster', 'json')) || [];
    summary.scouted_candidates = roster.length;

    await kv.put('summary', JSON.stringify(summary));
  } catch {}
}

export async function getFeedData(kv: KVNamespaceLike | undefined): Promise<any> {
  if (!kv) {
    return {
      summary: {
        active_students: 1,
        total_students_tracked: 1,
        studious_ratio: 80,
        total_questions: 10,
        total_derivations: 4,
        scouted_candidates: 1,
      },
      events: [],
      candidates: [],
      students: [],
    };
  }

  const [summary, events, candidates] = await Promise.all([
    kv.get('summary', 'json'),
    kv.get('recent_events', 'json'),
    kv.get('roster', 'json'),
  ]);

  return {
    summary: summary || {
      active_students: 1,
      total_students_tracked: 1,
      studious_ratio: 80,
      total_questions: 12,
      total_derivations: 4,
      scouted_candidates: (candidates && candidates.length) || 0,
    },
    events: events || [],
    candidates: candidates || [],
    students: candidates || [],
  };
}
