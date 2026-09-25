import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aevra_mobile/api/aevra_api_client.dart';
import 'package:aevra_mobile/api/models.dart';
import 'package:aevra_mobile/screens/advanced_analytics_screen.dart';
import 'package:aevra_mobile/state/app_state.dart';
import 'package:aevra_mobile/theme/aevra_theme.dart';

class AdvancedApi extends AevraApiClient {
  @override
  Future<Map<String, dynamic>> advancedInsights(
          String token,
          String workspaceId,
          String draft,
          String alternativeDraft,
          String platform) async =>
      {
        'version': 'test',
        'generated_at': '2026-09-24',
        'content_map': {
          'status': 'ready',
          'explanation': 'Related wording, not quality.',
          'explained_variance': 0.8,
          'points': [
            {
              'id': 'a',
              'caption': 'Coffee morning',
              'platform': 'instagram',
              'x': 0.5,
              'y': 0.5,
              'cluster': 0,
              'engagement_rate': 0
            }
          ],
          'clusters': [
            {'id': 0, 'label': 'coffee'}
          ]
        },
        'comparison': {
          'status': 'needs_data',
          'explanation': 'More labels needed.'
        },
        'data_quality': {
          'explanation': 'Missing observations are not zero engagement.',
          'coverage_percent': null,
          'matched_posts': 0,
          'mature_posts': 0,
          'freshness_hours': null,
          'observed_days': 0,
          'missing_days': 35,
          'timeline': List.generate(
              35,
              (i) => {
                    'date':
                        '2026-09-${(i % 28 + 1).toString().padLeft(2, '0')}',
                    'observed_posts': 0
                  }),
          'drift': {
            'status': 'needs_data',
            'explanation': 'At least ten posts per period.',
            'previous_start': '2026-08-19',
            'recent_start': '2026-09-02',
            'window_end': '2026-09-16'
          }
        }
      };
}

void main() {
  testWidgets('Advanced map and missing-data calendar fit 320px',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final state = AppState(client: AdvancedApi())
      ..token = 'test'
      ..workspace = Workspace(id: 'w', name: 'Studio', timezone: 'UTC');
    await tester.pumpWidget(MaterialApp(
        theme: AevraTheme.light, home: AdvancedAnalyticsScreen(state: state)));
    await tester.ensureVisible(find.text('Run advanced analysis'));
    await tester.tap(find.text('Run advanced analysis'));
    await tester.pumpAndSettle();
    expect(find.text('Content-performance map'), findsOneWidget);
    expect(find.text('Draft comparison lab'), findsOneWidget);
    expect(find.text('Data health & distribution shifts'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byType(TextField).first, 'Changed draft');
    await tester.pump();
    expect(find.text('Inputs changed. Run again to refresh these results.'),
        findsOneWidget);
  });
}
