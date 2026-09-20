import 'package:flutter_test/flutter_test.dart';
import 'package:cine_verse/screens/home_screen.dart';

void main() {
  group('libraryGridColumnCount', () {
    test('uses two columns on phone widths', () {
      expect(libraryGridColumnCount(320), 2);
      expect(libraryGridColumnCount(600), 2);
    });

    test('uses three columns on medium widths', () {
      expect(libraryGridColumnCount(601), 3);
      expect(libraryGridColumnCount(900), 3);
    });

    test('uses four columns on wide layouts', () {
      expect(libraryGridColumnCount(901), 4);
      expect(libraryGridColumnCount(1440), 4);
    });
  });
}
