import 'package:flutter_riverpod/legacy.dart';

import '../services/controller.dart';

final controllerProvider = ChangeNotifierProvider<DoomWalkController>(
  (ref) => throw StateError('controllerProvider must be overridden'),
);
