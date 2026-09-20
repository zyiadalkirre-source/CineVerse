import 'package:flutter_test/flutter_test.dart';
import '../lib/screens/home_screen.dart';

void main() {
  group('libraryGridColumnCount', () {
    test('uses two columns on phone widths', () {
      expect(libraryGridColumnCount(320), 2);
      expect(libraryGridColumnCount(480), 2);
    });

    test('uses three columns on medium widths', () {
      expect(libraryGridColumnCount(520), 3);
      expect(libraryGridColumnCount(899), 3);
    });

    test('uses four columns on wide layouts', () {
      expect(libraryGridColumnCount(900), 4);
      expect(libraryGridColumnCount(1440), 4);
    });
  });
}
