import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yo/models/party_session.dart';
import 'package:yo/pages/live_party_screen.dart';

void main() {
  testWidgets(
    'active warning shows once, does not queue duplicates, and resets',
    (tester) async {
      final states = StreamController<PartySessionState>.broadcast(sync: true);
      final messengerKey = GlobalKey<ScaffoldMessengerState>();
      addTearDown(states.close);
      await tester.pumpWidget(_WarningHarness(states.stream, messengerKey));

      const warning = PartySessionState.active(
        partyId: 'room',
        role: PartyRole.listener,
        generation: 1,
        warning: PartyFailureCode.network,
      );
      states
        ..add(warning)
        ..add(warning);
      await tester.pump();
      expect(
        find.text(
          'The network request failed. Please check your connection and retry.',
        ),
        findsOneWidget,
      );

      messengerKey.currentState!.hideCurrentSnackBar();
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);

      states.add(
        const PartySessionState.active(
          partyId: 'room',
          role: PartyRole.listener,
          generation: 1,
        ),
      );
      await tester.pump();
      states.add(warning);
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
    },
  );
}

class _WarningHarness extends StatelessWidget {
  const _WarningHarness(this.states, this.messengerKey);

  final Stream<PartySessionState> states;
  final GlobalKey<ScaffoldMessengerState> messengerKey;

  @override
  Widget build(BuildContext context) => MaterialApp(
    scaffoldMessengerKey: messengerKey,
    home: Scaffold(body: _WarningListener(states)),
  );
}

class _WarningListener extends StatefulWidget {
  const _WarningListener(this.states);

  final Stream<PartySessionState> states;

  @override
  State<_WarningListener> createState() => _WarningListenerState();
}

class _WarningListenerState extends State<_WarningListener> {
  final notice = PartyWarningNotice();
  StreamSubscription<PartySessionState>? subscription;

  @override
  void initState() {
    super.initState();
    subscription = widget.states.listen((state) => notice.show(context, state));
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}
