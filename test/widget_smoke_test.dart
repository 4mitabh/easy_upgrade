import 'package:easy_upgrade/easy_upgrade.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('EasyUpgrade renders its child and tolerates a missing platform',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: EasyUpgrade(
          // Tests run on the host (no iOS/Android channels available); the
          // checker should return severity=none without throwing.
          enabledInDebug: true,
          initialDelay: Duration.zero,
          child: Scaffold(body: Text('child rendered')),
        ),
      ),
    );

    expect(find.text('child rendered'), findsOneWidget);
    // Drain pending timers so the test exits cleanly.
    await tester.pump(const Duration(seconds: 1));
  });
}
