import 'package:flutter_test/flutter_test.dart';
import 'package:questionx/database.dart';

void main() {
  group('looksLikeQuestionId', () {
    test('matches real bank IDs across every exam prefix', () {
      const ids = [
        'JEE_Main_2020_Jan07_S2_Phy_22',
        'JEE_Adv_2024_P1_Math_8',
        'NEET_2013_Bio_5',
        'AIPMT_2005_Phy_1',
        'CBSE_2019_Chem_3',
      ];
      for (final id in ids) {
        expect(looksLikeQuestionId(id), isTrue, reason: id);
      }
    });

    test('is case-insensitive and tolerates surrounding whitespace', () {
      expect(looksLikeQuestionId('jee_main_2020_jan07_s2_phy_22'), isTrue);
      expect(looksLikeQuestionId('  JEE_Main_2020_Jan07_S2_Phy_22  '), isTrue);
    });

    test('matches a partial ID prefix (so it narrows as you type)', () {
      expect(looksLikeQuestionId('JEE_Main_2020'), isTrue);
    });

    test('does NOT trigger on ordinary text search', () {
      const queries = [
        '',
        'newton',
        'force and motion',
        'kinematics',
        'p-n junction',
        'JEE Main', // has a space -> a normal search, not an ID
        'neetprep', // no underscore after the exam token
        'physics',
      ];
      for (final q in queries) {
        expect(looksLikeQuestionId(q), isFalse, reason: '"$q"');
      }
    });
  });
}
