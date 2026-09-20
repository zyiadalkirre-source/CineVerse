import 'package:flutter_test/flutter_test.dart';
import 'package:cineverse/core/constants.dart';

void main() {
  test('sync schema constants are versioned and stable', () {
    expect(AppConstants.dbVersion, 6);
    expect(AppConstants.tableSyncOutbox, 'sync_outbox');
    expect(AppConstants.tableSyncState, 'sync_state');
  });
}
