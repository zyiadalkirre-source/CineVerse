import 'package:flutter_test/flutter_test.dart';
import '../lib/screens/stats_screen.dart';

void main() {
  group('statisticsGridRows', () {
    test('keeps five stat cards in a 2 + 2 + 1 layout', () {
      expect(
        statisticsGridRows(5),
        const [
          [0, 1],
          [2, 3],
          [4],
        ],
      );
    });

    test('keeps four cards in two balanced rows', () {
      expect(
        statisticsGridRows(4),
        const [
          [0, 1],
          [2, 3],
        ],
      );
    });

    test('handles empty and custom column counts', () {
      expect(statisticsGridRows(0), isEmpty);
      expect(
        statisticsGridRows(5, columns: 3),
        const [
          [0, 1, 2],
          [3, 4],
        ],
      );
    });
  });
}
