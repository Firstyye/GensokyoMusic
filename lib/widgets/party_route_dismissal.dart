import 'package:flutter/widgets.dart';

/// Removes the party screen itself, even when another route is displayed on
/// top of it (for example, the full player).
void removePartyRoute(BuildContext context) {
  final route = ModalRoute.of(context);
  if (route == null || !route.isActive) return;
  Navigator.of(context).removeRoute(route);
}
