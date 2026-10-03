import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// The plugin's platform contract lets layout tests avoid native media players.
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'package:aevra_mobile/screens/auth_screen.dart';
import 'package:aevra_mobile/main.dart' show MobileShell;
import 'package:aevra_mobile/api/aevra_api_client.dart';
import 'package:aevra_mobile/widgets/advanced_ui.dart';
import 'package:aevra_mobile/screens/overview_screen.dart';
import 'package:aevra_mobile/api/models.dart';
import 'package:aevra_mobile/state/app_state.dart';
import 'package:aevra_mobile/theme/aevra_theme.dart';
import 'package:aevra_mobile/widgets/vae_ui.dart';

class _LocalVideoPlatform extends VideoPlayerPlatform {
  int _nextId = 0;

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async =>
      ++_nextId;

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => Stream.value(VideoEvent(
      eventType: VideoEventType.initialized,
      duration: const Duration(seconds: 10),
      size: const Size(720, 1280)));

  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const ColoredBox(color: Color(0xFF171014));

  @override
  Future<void> dispose(int playerId) async {}

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> play(int playerId) async {}

  @override
  Future<void> pause(int playerId) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;
}

Widget _host(Widget child,
        {required ThemeData theme,
        double textScale = 1,
        GlobalKey? captureKey}) =>
    RepaintBoundary(
      key: captureKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: true,
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        home: child,
      ),
    );

Future<void> _size(WidgetTester tester, double width) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 852);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  const output = String.fromEnvironment('PREMIUM_CAPTURE_DIR');
  if (output.isEmpty) return;
  await tester.runAsync(() async {
    for (final asset in [
      'vae_creator_icon_256.png',
      'vae_admin_icon_256.png'
    ]) {
      await precacheImage(
          AssetImage('assets/branding/$asset'), key.currentContext!);
    }
  });
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final shadowsDisabled = debugDisableShadows;
  try {
    debugDisableShadows = false;
    void repaint(RenderObject object) {
      object.markNeedsPaint();
      object.visitChildren(repaint);
    }

    repaint(boundary);
    await tester.pump();
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final directory = await Directory(output).create(recursive: true);
      await File('${directory.path}/$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
    });
  } finally {
    debugDisableShadows = shadowsDisabled;
  }
}

class _AdminPreviewApi extends AevraApiClient {
  @override
  Future<Map<String, dynamic>> adminOverview(String token) async => {
        'users_total': 24,
        'users_approved': 21,
        'totals': {'generated_assets': 186, 'published': 72},
        'platforms': [
          {
            'platform': 'instagram',
            'connected': 16,
            'channels': 18,
            'published': 72,
            'impressions': 12640,
            'engagements': 842
          }
        ],
        'users': <Map<String, dynamic>>[],
      };

  @override
  Future<List<Map<String, dynamic>>> adminPayments(String token) async => [];
}

AppState _populatedState({AevraApiClient? client}) => AppState(client: client)
  ..workspace = Workspace(id: 'studio', name: 'Studio', timezone: 'UTC')
  ..assets = [
    MediaAsset(
        id: 'campaign-cover',
        filename: 'Autumn campaign cover',
        mediaType: 'image',
        status: 'ready',
        downloadUrl: null,
        createdAt: '2026-09-28T10:00:00Z'),
    MediaAsset(
        id: 'launch-reel',
        filename: 'Behind the scenes launch reel',
        mediaType: 'video',
        status: 'ready',
        downloadUrl: null,
        createdAt: '2026-09-28T11:00:00Z'),
  ]
  ..scheduled = [
    ScheduledPost(
        id: 'post-one',
        scheduledFor: '2026-09-30T12:30:00Z',
        status: 'scheduled',
        text:
            'A new season of thoughtful details. Meet our autumn collection.'),
    ScheduledPost(
        id: 'post-two',
        scheduledFor: '2026-10-01T14:00:00Z',
        status: 'scheduled',
        text: 'A closer look at the people and ideas behind the collection.'),
  ]
  ..accounts = [
    SocialAccount(
        id: 'instagram',
        platform: 'instagram',
        displayName: 'Studio',
        status: 'connected'),
  ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Use the shipped fonts so text wrapping reflects the actual product.
    for (final (family, assets) in [
      (
        'Manrope',
        ['Manrope-Regular.ttf', 'Manrope-SemiBold.ttf', 'Manrope-Bold.ttf']
      ),
      ('PlayfairDisplay', ['PlayfairDisplay-Medium.ttf']),
      ('JetBrainsMono', ['JetBrainsMono-Regular.ttf']),
    ]) {
      final loader = FontLoader(family);
      for (final asset in assets) {
        loader.addFont(rootBundle.load('assets/fonts/$asset'));
      }
      await loader.load();
    }
    final icons = FontLoader('packages/lucide_icons_flutter/Lucide')
      ..addFont(
          rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'));
    await icons.load();
  });

  setUp(() {
    VideoPlayerPlatform.instance = _LocalVideoPlatform();
    SharedPreferences.setMockInitialValues({'aevra.tour-complete': true});
  });

  for (final admin in [false, true]) {
    for (final light in [false, true]) {
      for (final (width, scale) in [
        (320.0, 2.0),
        (393.0, 1.0),
        (900.0, 1.0),
        (1280.0, 1.0)
      ]) {
        testWidgets(
            '${admin ? 'Admin' : 'Creator'} shell fits ${width.toInt()}px '
            '${light ? 'light' : 'dark'} at ${scale}x text', (tester) async {
          await _size(tester, width);
          final state =
              _populatedState(client: admin ? _AdminPreviewApi() : null)
                ..token = admin ? 'local-preview' : null
                ..user = AevraUser(
                    id: 'preview',
                    email: 'preview@example.com',
                    displayName: 'Alex',
                    isAdmin: admin);
          final sound = AevraSound();
          final pulse = ParticlePulse();
          addTearDown(state.dispose);
          addTearDown(sound.dispose);
          addTearDown(pulse.dispose);
          final captureKey = GlobalKey();
          await tester.pumpWidget(_host(
            AevraServices(
                sound: sound,
                pulse: pulse,
                child: MobileShell(
                    state: state,
                    sound: sound,
                    pulse: pulse,
                    darkMode: !light,
                    onToggleTheme: () {})),
            theme: light ? AevraTheme.light : AevraTheme.dark,
            textScale: scale,
            captureKey: captureKey,
          ));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byTooltip('Open profile'), findsOneWidget);
          expect(find.byTooltip('Commands'),
              width >= 900 ? findsNWidgets(2) : findsOneWidget);
          if (width == 393) {
            await _capture(tester, captureKey,
                '${admin ? 'admin' : 'creator'}-${light ? 'light' : 'dark'}-workspace');
          }
          if (width == 1280) {
            await _capture(tester, captureKey,
                '${admin ? 'admin' : 'creator'}-${light ? 'light' : 'dark'}-desktop');
            await tester.tap(find.byTooltip('Collapse sidebar'));
            await tester.pumpAndSettle();
            expect(find.byTooltip('Expand sidebar'), findsOneWidget);
            expect(tester.takeException(), isNull);
          }
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        });
      }
    }
  }

  for (final width in [320.0, 393.0, 430.0, 900.0, 1280.0]) {
    for (final admin in [false, true]) {
      for (final light in [false, true]) {
        for (final scale in [1.0, 1.4]) {
          testWidgets(
              '${admin ? 'Admin' : 'Creator'} auth fits ${width.toInt()}px '
              '${light ? 'light' : 'dark'} at ${scale}x text', (tester) async {
            await _size(tester, width);
            final state = AppState();
            final captureKey = GlobalKey();
            addTearDown(state.dispose);
            await tester.pumpWidget(_host(
                AuthScreen(state: state, initialAdminPortal: admin),
                theme: light ? AevraTheme.light : AevraTheme.dark,
                textScale: scale,
                captureKey: captureKey));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(find.byType(TextField), findsNWidgets(2));
            if (width == 393 && scale == 1) {
              await _capture(tester, captureKey,
                  '${admin ? 'admin' : 'creator'}-${light ? 'light' : 'dark'}-landing');
            }
            await tester.ensureVisible(find.byType(TextField).last);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            if (width == 393 && scale == 1) {
              await tester.ensureVisible(find.byType(AutofillGroup));
              await tester.pumpAndSettle();
              await _capture(tester, captureKey,
                  '${admin ? 'admin' : 'creator'}-${light ? 'light' : 'dark'}-form');
            }
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
          });
        }
      }
    }
  }

  testWidgets(
      'Creator registration and portal switch stay reachable on a narrow phone',
      (tester) async {
    await _size(tester, 320);
    final state = AppState();
    addTearDown(state.dispose);
    await tester.pumpWidget(_host(AuthScreen(state: state),
        theme: AevraTheme.dark, textScale: 1.4));
    await tester.pumpAndSettle();
    final registration = find.widgetWithText(TextButton, 'Create account');
    await tester.ensureVisible(registration);
    await tester.pumpAndSettle();
    await tester.tap(registration);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(4));
    expect(tester.takeException(), isNull);
    final switchPortal = find.text('Administrator access');
    await tester.ensureVisible(switchPortal);
    await tester.pumpAndSettle();
    await tester.tap(switchPortal);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('Sign in as administrator'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  for (final admin in [false, true]) {
    testWidgets(
        '${admin ? 'Admin' : 'Creator'} navigation keeps every destination interactive',
        (tester) async {
      await _size(tester, 320);
      final selected = <int>[];
      var profileCount = 0;
      await tester.pumpWidget(_host(
        Scaffold(
          body: const SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: VaeMetricCard('Total media assets', '12,456',
                      hint: 'Ready to publish')),
              SizedBox(width: 12),
              Expanded(
                  child: VaeMetricCard('Scheduled posts', '256',
                      hint: 'Across your channels')),
            ]),
          ),
          bottomNavigationBar: VaeBottomNav(
              admin: admin,
              index: 0,
              onSelected: selected.add,
              onProfile: () => profileCount++),
        ),
        theme: admin ? AevraTheme.adminLight : AevraTheme.dark,
        textScale: 1.4,
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final items = find.descendant(
          of: find.byType(VaeBottomNav), matching: find.byType(InkWell));
      expect(items, findsNWidgets(5));
      for (var i = 0; i < items.evaluate().length; i++) {
        await tester.tap(items.at(i));
        await tester.pump();
      }
      expect(selected, admin ? [0, 1, 2, 3, 4] : [0, 2, 1, 3]);
      expect(profileCount, admin ? 0 : 1);
      expect(tester.takeException(), isNull);
    });
  }

  for (final light in [false, true]) {
    for (final (width, scale) in [(320.0, 1.4), (320.0, 2.0), (393.0, 1.0)]) {
      testWidgets(
          'Populated home fits ${width.toInt()}px '
          '${light ? 'light' : 'dark'} at ${scale}x text', (tester) async {
        await _size(tester, width);
        final state = _populatedState();
        addTearDown(state.dispose);
        final captureKey = GlobalKey();
        final destinations = <int>[];
        var campaignsOpened = 0;
        await tester.pumpWidget(_host(
          Scaffold(
            body: OverviewScreen(
                state: state,
                onNavigate: destinations.add,
                onCampaigns: () => campaignsOpened++),
            bottomNavigationBar: VaeBottomNav(
                index: 0, onSelected: destinations.add, onProfile: () {}),
          ),
          theme: light ? AevraTheme.light : AevraTheme.dark,
          textScale: scale,
          captureKey: captureKey,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (width == 393) {
          await _capture(
              tester, captureKey, 'home-${light ? 'light' : 'dark'}');
        }
        await tester.tap(find.text('Create media'));
        expect(destinations.last, 1);
        await tester.ensureVisible(find.text('Autumn campaign cover'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (width == 393) {
          await _capture(
              tester, captureKey, 'home-${light ? 'light' : 'dark'}-library');
        }
        await tester.tap(find.text('Autumn campaign cover'));
        await tester.pumpAndSettle();
        expect(state.publishAssetId, 'campaign-cover');
        expect(destinations.last, 2);
        await tester.ensureVisible(find.text('Campaigns'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Campaigns'));
        expect(campaignsOpened, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
