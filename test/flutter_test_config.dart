import 'dart:async';

import 'package:puzzle_hub/core/ui/candy.dart';

/// Chay truoc moi file test: tat nen chuyen dong de pumpAndSettle khong treo.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  CandyMotion.animatedBackground = false;
  await testMain();
}
