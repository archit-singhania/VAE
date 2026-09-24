import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aevra_mobile/api/aevra_api_client.dart';
import 'package:aevra_mobile/api/models.dart';
import 'package:aevra_mobile/screens/media_screen.dart';
import 'package:aevra_mobile/screens/advanced_screen.dart';
import 'package:aevra_mobile/screens/overview_screen.dart';
import 'package:aevra_mobile/screens/schedule_screen.dart';
import 'package:aevra_mobile/state/app_state.dart';
import 'package:aevra_mobile/theme/aevra_theme.dart';

class FakeCreatorApi extends AevraApiClient {
  int generations = 0;
  int sources = 0;
  @override
  Future<KnowledgeDocument> ingestSource(
      String token, String workspaceId, String title, String content,
      {String? brandId}) async {
    sources++;
    return KnowledgeDocument(
        id: 'source-$sources',
        title: title,
        sourceType: 'markdown',
        contentLength: content.length,
        status: 'ready');
  }

  @override
  Future<List<MediaAsset>> generateImage(
      String token, String workspaceId, String prompt,
      {String aspectRatio = '1:1'}) async {
    generations++;
    return [
      MediaAsset(
          id: '$generations',
          filename: 'Visual.png',
          mediaType: 'image',
          status: 'ready',
          downloadUrl: null,
          createdAt: '2026-09-22T00:00:00Z')
    ];
  }
}

void main() {
  AppState state(FakeCreatorApi api) => AppState(client: api)
    ..token = 'test-only'
    ..workspace = Workspace(id: 'test', name: 'Studio', timezone: 'UTC');

  for (final light in [false, true]) {
    testWidgets('Home fits a 320px screen in ${light ? 'light' : 'dark'} mode',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final s = state(FakeCreatorApi());
      await tester.pumpWidget(MaterialApp(
          theme: light ? AevraTheme.light : AevraTheme.dark,
          home: Scaffold(body: OverviewScreen(state: s))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Media assets'), findsOneWidget);
    });
  }

  testWidgets('Create defaults to one output and retains the draft on re-entry',
      (tester) async {
    final api = FakeCreatorApi();
    final s = state(api);
    Widget screen() => MaterialApp(
        theme: AevraTheme.light, home: Scaffold(body: MediaScreen(state: s)));
    await tester.pumpWidget(screen());
    await tester.enterText(find.byType(TextField), 'A vase in morning light');
    await tester.ensureVisible(find.text('Generate image'));
    await tester.tap(find.text('Generate image'));
    await tester.pumpAndSettle();
    expect(find.text('Caption & hashtags'), findsWidgets);
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    expect(api.generations, 1);
    expect(s.assets.length, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(screen());
    expect(find.text('A vase in morning light'), findsOneWidget);
  });

  testWidgets('Publish rejects an empty channel selection before delivery',
      (tester) async {
    final s = state(FakeCreatorApi());
    await tester.pumpWidget(MaterialApp(
        theme: AevraTheme.dark,
        home: Scaffold(body: ScheduleScreen(state: s))));
    await tester.ensureVisible(find.text('Review post'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review post'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a channel and add a caption.'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('Source ingestion validates input and adds the returned document',
      (tester) async {
    final api = FakeCreatorApi();
    final s = state(api);
    await tester.pumpWidget(
        MaterialApp(theme: AevraTheme.light, home: AdvancedScreen(state: s)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add source'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add source'));
    await tester.pumpAndSettle();
    expect(api.sources, 0);
    expect(find.text('This field is required.'), findsNWidgets(2));
    await tester.enterText(find.widgetWithText(TextFormField, 'Source title'),
        'Studio guidelines');
    await tester.enterText(find.widgetWithText(TextFormField, 'Source text'),
        'Use a calm voice and warm morning light.');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add source'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add source'));
    await tester.pumpAndSettle();
    expect(api.sources, 1);
    expect(s.documents.single.title, 'Studio guidelines');
    expect(find.text('Source added to brand knowledge.'), findsOneWidget);
  });
}
