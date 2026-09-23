import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aevra_mobile/api/aevra_api_client.dart';
import 'package:aevra_mobile/api/models.dart';
import 'package:aevra_mobile/screens/ml_insights_screen.dart';
import 'package:aevra_mobile/state/app_state.dart';
import 'package:aevra_mobile/theme/aevra_theme.dart';

class FakeMlApi extends AevraApiClient {
  String? sentDraft;
  @override
  Future<Map<String, dynamic>> mlInsights(
      String token, String workspaceId, String draft, String platform) async {
    sentDraft = draft;
    return {
      'model_version': 'test-model',
      'features': [
        {
          'title': 'Engagement prediction',
          'status': 'unreliable',
          'explanation': 'Validation did not beat the baseline.',
          'sample_count': 30,
          'minimum_samples': 30,
          'items': [],
          'method': 'Ridge regression',
          'diagnostics': {'holdout_mae': 4}
        }
      ],
      'audit': {
        'history_capped': false,
        'notes': ['Human review required.']
      }
    };
  }
}

void main() {
  testWidgets('ML analysis fits 320px and displays withheld predictions',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = FakeMlApi();
    final state = AppState(client: api)
      ..token = 'test'
      ..workspace = Workspace(id: 'workspace', name: 'Test', timezone: 'UTC');
    await tester.pumpWidget(MaterialApp(
        theme: AevraTheme.light, home: MlInsightsScreen(state: state)));
    await tester.enterText(find.byType(TextField), 'Coffee morning');
    await tester.ensureVisible(find.text('Analyze workspace'));
    await tester.tap(find.text('Analyze workspace'));
    await tester.pumpAndSettle();
    expect(api.sentDraft, 'Coffee morning');
    expect(find.text('Prediction withheld'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byType(TextField), 'New draft');
    await tester.pump();
    expect(find.text('Inputs changed. Analyze again to refresh these results.'),
        findsOneWidget);
  });
}
