import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yo/widgets/party_route_dismissal.dart';

void main() {
  testWidgets(
    'room closure removes the party route without popping its child route',
    (tester) async {
      BuildContext? partyContext;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Column(
                children: [
                  const Text('Home'),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (context) => Builder(
                            builder: (context) {
                              partyContext = context;
                              return Scaffold(
                                body: TextButton(
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const Scaffold(
                                        body: Text('Now Playing'),
                                      ),
                                    ),
                                  ),
                                  child: const Text('Open Player'),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                    child: const Text('Open Party'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Party'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Player'));
      await tester.pumpAndSettle();

      removePartyRoute(partyContext!);
      await tester.pumpAndSettle();

      expect(find.text('Now Playing'), findsOneWidget);
      Navigator.of(tester.element(find.text('Now Playing'))).pop();
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Open Player'), findsNothing);
    },
  );
}
