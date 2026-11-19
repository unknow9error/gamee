import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const captureKey = ValueKey('verified-widget-capture');

/// A rendered widget fixture, explicitly separate from native device evidence.
Future<void> captureWidgetFixture(
  WidgetTester tester,
  String output, {
  List<ImageProvider> images = const [],
}) async {
  final element = tester.element(find.byKey(captureKey));
  if (images.isNotEmpty) {
    await tester.runAsync(
      () => Future.wait(
        images.map((provider) => precacheImage(provider, element)),
      ),
    );
  }
  await tester.pump();
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(captureKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) throw StateError('Widget capture produced no PNG');
    final file = File(output);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
    image.dispose();
  });
}
