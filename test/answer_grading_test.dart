import 'package:flutter_test/flutter_test.dart';
import 'package:questionx/utils/answer_grading.dart';

void main() {
  group('typeOf', () {
    test('single-letter MCQ', () {
      expect(AnswerGrading.typeOf(options: ['a', 'b', 'c', 'd'], answerKey: 'C'),
          QType.mcqSingle);
    });
    test('multi-correct MCQ', () {
      expect(AnswerGrading.typeOf(options: ['a', 'b', 'c', 'd'], answerKey: 'A,C'),
          QType.mcqMulti);
    });
    test('numeric (no options)', () {
      expect(AnswerGrading.typeOf(options: const [], answerKey: '400'),
          QType.numeric);
      expect(AnswerGrading.typeOf(options: const ['', '', '', ''], answerKey: '4'),
          QType.numeric);
    });
    test('bonus', () {
      expect(AnswerGrading.typeOf(options: const [], answerKey: 'BONUS'),
          QType.bonus);
    });
  });

  group('mcqSingle grading', () {
    test('correct / wrong / case-insensitive', () {
      expect(AnswerGrading.isCorrect(type: QType.mcqSingle, userAnswer: 'C', answerKey: 'C'), isTrue);
      expect(AnswerGrading.isCorrect(type: QType.mcqSingle, userAnswer: 'a', answerKey: 'A'), isTrue);
      expect(AnswerGrading.isCorrect(type: QType.mcqSingle, userAnswer: 'A', answerKey: 'C'), isFalse);
      expect(AnswerGrading.isCorrect(type: QType.mcqSingle, userAnswer: null, answerKey: 'C'), isFalse);
    });
  });

  group('mcqMulti grading (order-insensitive set equality)', () {
    test('exact set correct', () {
      expect(AnswerGrading.isCorrect(type: QType.mcqMulti, userAnswer: 'A,C', answerKey: 'A,C'), isTrue);
      expect(AnswerGrading.isCorrect(type: QType.mcqMulti, userAnswer: 'C,A', answerKey: 'A,C'), isTrue);
    });
    test('partial or extra is wrong', () {
      expect(AnswerGrading.isCorrect(type: QType.mcqMulti, userAnswer: 'A', answerKey: 'A,C'), isFalse);
      expect(AnswerGrading.isCorrect(type: QType.mcqMulti, userAnswer: 'A,B,C', answerKey: 'A,C'), isFalse);
    });
  });

  group('numeric grading', () {
    test('exact and decimal-equivalent', () {
      expect(AnswerGrading.isCorrect(type: QType.numeric, userAnswer: '400', answerKey: '400'), isTrue);
      expect(AnswerGrading.isCorrect(type: QType.numeric, userAnswer: '4.0', answerKey: '4'), isTrue);
      expect(AnswerGrading.isCorrect(type: QType.numeric, userAnswer: '5', answerKey: '4'), isFalse);
    });
    test('tolerance', () {
      expect(AnswerGrading.isCorrect(type: QType.numeric, userAnswer: '3.995', answerKey: '4'), isTrue);
    });
    test('range key aTOb (inclusive)', () {
      expect(AnswerGrading.isCorrect(type: QType.numeric, userAnswer: '40.5', answerKey: '40TO41'), isTrue);
      expect(AnswerGrading.isCorrect(type: QType.numeric, userAnswer: '41', answerKey: '40TO41'), isTrue);
      expect(AnswerGrading.isCorrect(type: QType.numeric, userAnswer: '39', answerKey: '40TO41'), isFalse);
    });
    test('OR alternatives', () {
      expect(AnswerGrading.isCorrect(type: QType.numeric, userAnswer: '8', answerKey: '2OR8'), isTrue);
      expect(AnswerGrading.isCorrect(type: QType.numeric, userAnswer: '2', answerKey: '2OR8'), isTrue);
      expect(AnswerGrading.isCorrect(type: QType.numeric, userAnswer: '5', answerKey: '2OR8'), isFalse);
      expect(AnswerGrading.isCorrect(type: QType.numeric, userAnswer: '3730', answerKey: '3730OR6460'), isTrue);
    });
    test('negative + latex noise', () {
      expect(AnswerGrading.isCorrect(type: QType.numeric, userAnswer: '-5242.41', answerKey: r'$$-$$5242.41'), isTrue);
    });
    test('non-numeric input is wrong, not a crash', () {
      expect(AnswerGrading.isCorrect(type: QType.numeric, userAnswer: 'abc', answerKey: '4'), isFalse);
    });
  });

  group('bonus', () {
    test('any attempt credited, empty not', () {
      expect(AnswerGrading.isCorrect(type: QType.bonus, userAnswer: '4', answerKey: 'BONUS'), isTrue);
      expect(AnswerGrading.isCorrect(type: QType.bonus, userAnswer: '', answerKey: 'BONUS'), isFalse);
    });
  });
}
