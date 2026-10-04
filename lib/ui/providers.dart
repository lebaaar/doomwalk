import 'package:flutter_riverpod/legacy.dart';

import '../services/controller.dart';

/// The process-wide controller; overridden in main() with the started one.
final controllerProvider = ChangeNotifierProvider<DoomWalkController>(
  (ref) => throw StateError('controllerProvider must be overridden'),
);
