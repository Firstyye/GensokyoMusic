import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yo/models/party_session.dart';
import 'package:yo/widgets/party_switch_confirmation.dart';

Widget _harness({
  required PartySessionState state,
  required List<bool> results,
}) {
  return MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () async {
            results.add(
              await showPartySwitchConfirmation(context, state, 'target'),
            );
          },
          child: const Text('Open party'),
        ),
      ),
    ),
  );
}

void main() {
  test('every typed failure has stable user-facing copy', () {
    for (final failure in PartyFailureCode.values) {
      expect(partyFailureMessage(failure), isNotEmpty);
    }
    expect(
      partyFailureMessage(PartyFailureCode.roomClosed),
      contains('ended before you could join'),
    );
    expect(partyFailureMessage(PartyFailureCode.network), contains('retry'));
    expect(
      partyFailureMessage(PartyFailureCode.permissionDenied),
      contains('account cannot perform'),
    );
    expect(
      partyFailureMessage(PartyFailureCode.unauthenticated),
      contains('sign in again'),
    );
  });

  testWidgets('host switch warning explains transfer or closure', (
    tester,
  ) async {
    final results = <bool>[];
    await tester.pumpWidget(
      _harness(
        state: const PartySessionState.active(
          partyId: 'current',
          role: PartyRole.host,
          generation: 1,
        ),
        results: results,
      ),
    );
    await tester.tap(find.text('Open party'));
    await tester.pumpAndSettle();
    expect(find.textContaining('transfer Host'), findsOneWidget);
    expect(find.textContaining('close if nobody remains'), findsOneWidget);
    await tester.tap(find.text('Switch'));
    await tester.pumpAndSettle();
    expect(results, [true]);
  });

  testWidgets('listener copy and Cancel return false', (tester) async {
    final results = <bool>[];
    await tester.pumpWidget(
      _harness(
        state: const PartySessionState.active(
          partyId: 'current',
          role: PartyRole.listener,
          generation: 1,
        ),
        results: results,
      ),
    );
    await tester.tap(find.text('Open party'));
    await tester.pumpAndSettle();
    expect(find.text('Leave Current Party?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(results, [false]);
  });

  testWidgets('barrier dismissal and Back return false', (tester) async {
    final results = <bool>[];
    await tester.pumpWidget(
      _harness(
        state: const PartySessionState.active(
          partyId: 'current',
          role: PartyRole.listener,
          generation: 1,
        ),
        results: results,
      ),
    );
    await tester.tap(find.text('Open party'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(results, [false]);

    await tester.tap(find.text('Open party'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(results, [false, false]);
  });

  testWidgets('inactive and same-room targets need no dialog', (tester) async {
    final results = <bool>[];
    await tester.pumpWidget(
      _harness(state: const PartySessionState.idle(), results: results),
    );
    await tester.tap(find.text('Open party'));
    await tester.pump();
    expect(results, [true]);
    expect(find.byType(AlertDialog), findsNothing);

    results.clear();
    await tester.pumpWidget(
      _harness(
        state: const PartySessionState.active(
          partyId: 'target',
          role: PartyRole.listener,
          generation: 2,
        ),
        results: results,
      ),
    );
    await tester.tap(find.text('Open party'));
    await tester.pump();
    expect(results, [true]);
    expect(find.byType(AlertDialog), findsNothing);
  });
}
