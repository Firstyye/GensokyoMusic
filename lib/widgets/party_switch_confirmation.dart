import 'package:flutter/material.dart';

import '../models/party_session.dart';

Future<bool> showPartySwitchConfirmation(
  BuildContext context,
  PartySessionState current,
  String targetPartyId,
) async {
  if (!current.isActive || current.partyId == targetPartyId) return true;

  final isHost = current.isHost;
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      title: Text(
        isHost ? 'Switch Party?' : 'Leave Current Party?',
        style: const TextStyle(color: Colors.white),
      ),
      content: Text(
        isHost
            ? 'Leaving will transfer Host to the member who joined first, or close if nobody remains.'
            : 'Leave Room ${current.partyId} and continue to the selected party?',
        style: const TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Switch'),
        ),
      ],
    ),
  );
  return result ?? false;
}

String partyFailureMessage(PartyFailureCode? failure) {
  return switch (failure) {
    PartyFailureCode.roomClosed =>
      'This room ended before you could join. Please choose another party.',
    PartyFailureCode.network =>
      'The network request failed. Please check your connection and retry.',
    PartyFailureCode.permissionDenied =>
      'This account cannot perform that party action.',
    PartyFailureCode.alreadyBusy =>
      'Another party action is still in progress. Please wait and retry.',
    PartyFailureCode.unauthenticated =>
      'Please sign in again before using Live Parties.',
    PartyFailureCode.unknown ||
    null => 'The party action could not be completed. Please try again.',
  };
}
