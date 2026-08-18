import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which section of the secretary screen is shown. Written by the side nav,
/// the drawer and the secretary screen itself, so navigating between
/// "Waiting Room" and "Patients" always works - no route change needed.
enum SecretaryTab { queue, patients }

final secretaryTabProvider =
    StateProvider<SecretaryTab>((ref) => SecretaryTab.queue);