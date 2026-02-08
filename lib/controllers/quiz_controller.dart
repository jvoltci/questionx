import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../database.dart';

class QuizState {
  final int currentQuestionIndex;
  final Map<String, String> selectedAnswers;
  final int elapsedSeconds;
  final bool isSubmitting;

  QuizState({
    this.currentQuestionIndex = 0,
    this.selectedAnswers = const {},
    this.elapsedSeconds = 0,
    this.isSubmitting = false,
  });

  QuizState copyWith({
    int? currentQuestionIndex,
    Map<String, String>? selectedAnswers,
    int? elapsedSeconds,
    bool? isSubmitting,
  }) {
    return QuizState(
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      selectedAnswers: selectedAnswers ?? this.selectedAnswers,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

class QuizController extends StateNotifier<QuizState> {
  Timer? _timer;

  QuizController() : super(QuizState());

  void startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
    });
  }

  void stopTimer() {
    _timer?.cancel();
  }

  void selectOption(String questionId, String option) {
    final newMap = Map<String, String>.from(state.selectedAnswers);
    newMap[questionId] = option;
    state = state.copyWith(selectedAnswers: newMap);
  }

  void nextQuestion(int total) {
    if (state.currentQuestionIndex < total - 1) {
      state = state.copyWith(
        currentQuestionIndex: state.currentQuestionIndex + 1,
      );
    }
  }

  void prevQuestion() {
    if (state.currentQuestionIndex > 0) {
      state = state.copyWith(
        currentQuestionIndex: state.currentQuestionIndex - 1,
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final quizControllerProvider =
    StateNotifierProvider.autoDispose<QuizController, QuizState>((ref) {
      return QuizController();
    });
