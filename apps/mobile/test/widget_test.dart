// Smoke tests for the Nocturne design system.
//
// These deliberately do NOT pump `AevraApp`. That widget calls
// `AppState.hydrate()` on init, which reads `flutter_secure_storage` over a
// platform channel; in a bare `flutter test` run there is no platform on the
// other end, so the test would depend on mocking an unrelated plugin just to
// prove that a theme exists. Testing the theme and the brand mark directly
// covers the same ground without that coupling.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aevra_mobile/theme/aevra_theme.dart';
import 'package:aevra_mobile/widgets/aevra_logo.dart';

void main() {
  group('AevraTheme', () {
    test('dark theme exposes the Nocturne tokens through its ColorScheme', () {
      final scheme = AevraTheme.dark.colorScheme;

      expect(scheme.brightness, Brightness.dark);
      expect(scheme.primary, AevraColors.accent);
      expect(scheme.onPrimary, AevraColors.accentInk);
      expect(scheme.secondary, AevraColors.jade);
      expect(scheme.tertiary, AevraColors.frost);
      expect(scheme.error, AevraColors.rose);
      expect(AevraTheme.dark.scaffoldBackgroundColor, AevraColors.bg);
    });

    test('light theme is the same system, not a different one', () {
      final scheme = AevraTheme.light.colorScheme;

      expect(scheme.brightness, Brightness.light);
      expect(scheme.primary, AevraLightColors.accent);
      expect(scheme.secondary, AevraLightColors.jade);
      expect(scheme.tertiary, AevraLightColors.frost);
      expect(AevraTheme.light.scaffoldBackgroundColor, AevraLightColors.bg);
    });

    test('both themes suppress the Material ink splash', () {
      for (final theme in [AevraTheme.dark, AevraTheme.light]) {
        expect(theme.splashFactory, NoSplash.splashFactory);
        expect(theme.highlightColor, Colors.transparent);
      }
    });
  });

  group('Brand mark', () {
    testWidgets('renders at the size it is given', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AevraTheme.dark,
          home: const Scaffold(body: Center(child: AevraMark(size: 44))),
        ),
      );

      expect(find.byType(AevraMark), findsOneWidget);
      expect(tester.getSize(find.byType(AevraMark)), const Size(44, 44));
    });

    testWidgets('wordmark combines the production mark and adaptive name',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AevraTheme.dark,
          home: const Scaffold(body: Center(child: AevraWordmark())),
        ),
      );

      expect(find.byType(AevraMark), findsOneWidget);
      expect(find.byType(RichText), findsWidgets);
    });
  });
}
