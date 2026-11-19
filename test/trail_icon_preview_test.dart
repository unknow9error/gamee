import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_trails/core/theme.dart';
import 'package:tiny_trails/shared/widgets/trail_icon.dart';

import 'support/widget_capture.dart';

const _captureFixtures = bool.fromEnvironment('CAPTURE_FIXTURES');

void main() {
  testWidgets('ink icon family paints at tool and navigation sizes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1040, 920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await (FontLoader(
      'Nunito',
    )..addFont(rootBundle.load('assets/fonts/Nunito.ttf'))).load();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: RepaintBoundary(
          key: captureKey,
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'tiny trails · little ink drawings',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '24 px tools  ·  32 px selected  ·  24 px on green',
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final kind in TrailIconKind.values)
                        Container(
                          width: 185,
                          height: 114,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.line),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                kind.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  TrailIcon(kind, size: 24),
                                  TrailIcon(kind, selected: true, size: 32),
                                  Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: AppColors.green,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: TrailIcon(
                                      kind,
                                      size: 24,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    if (_captureFixtures) {
      await captureWidgetFixture(tester, 'output/qa/ui-polish/icon-family.png');
    }
  });
}
