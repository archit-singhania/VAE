import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/analytics_screen.dart';
import 'screens/advanced_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/media_screen.dart';
import 'screens/overview_screen.dart';
import 'screens/schedule_screen.dart';
import 'state/app_state.dart';
import 'theme/aevra_theme.dart';
import 'widgets/advanced_ui.dart';
import 'widgets/aevra_logo.dart';
import 'widgets/shader_background.dart';
import 'widgets/vae_profile_sheet.dart';
import 'widgets/vae_ui.dart';

void main() => runApp(const AevraApp());

class AevraApp extends StatefulWidget {
  const AevraApp({super.key});

  @override
  State<AevraApp> createState() => _AevraAppState();
}

class _AevraAppState extends State<AevraApp> {
  late final AppState state;
  final AevraSound sound = AevraSound();
  final ParticlePulse pulse = ParticlePulse();
  bool darkMode = true;

  @override
  void initState() {
    super.initState();
    state = AppState();
    state.hydrate();
    sound.hydrate();
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) {
        setState(() => darkMode = prefs.getBool('vae.dark-mode') ?? true);
      }
    });
  }

  void _toggleTheme() {
    final next = !darkMode;
    setState(() => darkMode = next);
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setBool('vae.dark-mode', next));
  }

  @override
  void dispose() {
    state.dispose();
    sound.dispose();
    pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VAE',
      debugShowCheckedModeBanner: false,
      theme: darkMode ? AevraTheme.dark : AevraTheme.light,
      // Wrapped via `builder`, not `home`, so dialogs, bottom sheets and
      // overlay entries pushed onto the Navigator can still reach it —
      // anything under `home` alone would be invisible to those routes.
      builder: (context, child) =>
          AevraServices(sound: sound, pulse: pulse, child: child!),
      home: AnimatedBuilder(
        animation: state,
        builder: (context, _) {
          if (!state.hydrated) {
            return const _BootScreen();
          }
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: state.authenticated
                ? MobileShell(
                    key: const ValueKey('shell'),
                    state: state,
                    sound: sound,
                    pulse: pulse,
                    darkMode: darkMode,
                    onToggleTheme: _toggleTheme,
                  )
                : AuthScreen(
                    key: const ValueKey('auth'),
                    state: state,
                    onToggleTheme: _toggleTheme),
          );
        },
      ),
    );
  }
}

/// Shown while secure storage is being read. Uses the brand mark and a
/// shimmer rather than a bare spinner, so the very first frame already
/// looks like the product (#4, and stands in for the native splash until
/// the platform folders and icon assets exist).
class _BootScreen extends StatelessWidget {
  const _BootScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AevraColors.bg,
      body: Stack(
        children: [
          const Positioned.fill(
              child: RepaintBoundary(child: ShaderBackground())),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AevraMark(size: 52),
                const SizedBox(height: AevraSpace.lg),
                Text('VAE', style: AevraType.eyebrow(color: AevraColors.muted)),
                const SizedBox(height: AevraSpace.md),
                const SizedBox(
                  width: 104,
                  child: ShimmerBox(height: 3, radius: AevraRadius.pill),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MobileShell extends StatefulWidget {
  const MobileShell({
    super.key,
    required this.state,
    required this.sound,
    required this.pulse,
    required this.darkMode,
    required this.onToggleTheme,
  });

  final AppState state;
  final AevraSound sound;
  final ParticlePulse pulse;
  final bool darkMode;
  final VoidCallback onToggleTheme;

  @override
  State<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends State<MobileShell> {
  int index = 0;
  final GlobalKey _themeButtonKey = GlobalKey();
  OverlayEntry? _wipeEntry;
  bool _tourChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowTour());
  }

  @override
  void dispose() {
    _wipeEntry?.remove();
    _wipeEntry = null;
    super.dispose();
  }

  /// #8 — first-run tour, gated on a SharedPreferences flag.
  Future<void> _maybeShowTour() async {
    if (_tourChecked) return;
    _tourChecked = true;
    if (await hasCompletedTour()) return;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) =>
          OnboardingSheet(onDone: () => Navigator.of(dialogContext).pop()),
    );
  }

  /// #9 — theme wipe. The circle grows from the toggle button, the theme
  /// flips while the screen is fully covered, then the cover fades out.
  void _toggleThemeWithWipe() {
    if (_wipeEntry != null) return; // already mid-wipe
    widget.sound.tap();

    final overlay = Overlay.of(context);
    final box =
        _themeButtonKey.currentContext?.findRenderObject() as RenderBox?;
    final center = box == null
        ? MediaQuery.of(context).size.center(Offset.zero)
        : box.localToGlobal(box.size.center(Offset.zero));

    if (reduceMotion(context)) {
      widget.onToggleTheme();
      return;
    }

    final entry = OverlayEntry(
      builder: (_) => ThemeWipeOverlay(
        center: center,
        toDark: !widget.darkMode,
        onMidpoint: widget.onToggleTheme,
        onComplete: () {
          _wipeEntry?.remove();
          _wipeEntry = null;
        },
      ),
    );
    _wipeEntry = entry;
    overlay.insert(entry);
  }

  /// #5 — command palette, the mobile counterpart of web's ⌘K.
  void _openCommandPalette() {
    widget.sound.tap();
    showCommandPalette(context, [
      CommandAction(
          label: 'Brand knowledge & sources',
          hint: 'More',
          icon: Icons.menu_book_outlined,
          run: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => AdvancedScreen(state: widget.state)))),
      if (widget.state.user?.isAdmin == true)
        CommandAction(
            label: 'Admin dashboard',
            hint: 'Admin',
            icon: Icons.admin_panel_settings_outlined,
            run: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) =>
                    AdvancedScreen(state: widget.state, admin: true)))),
      CommandAction(
          label: 'Profile',
          hint: 'Account and appearance',
          icon: Icons.person_outline,
          run: _openProfile),
      CommandAction(
        label: 'Go to Home',
        hint: 'Media, channel, and publishing summary',
        icon: Icons.space_dashboard_outlined,
        run: () => _go(0),
      ),
      CommandAction(
        label: 'Go to Create',
        hint: 'Create images and captions',
        icon: Icons.auto_awesome_outlined,
        run: () => _go(1),
      ),
      CommandAction(
        label: 'Go to Publish',
        hint: 'Upcoming scheduled posts',
        icon: Icons.schedule_outlined,
        run: () => _go(2),
      ),
      CommandAction(
        label: 'Go to Analytics',
        hint: 'Publishing and engagement signal',
        icon: Icons.insights_outlined,
        run: () => _go(3),
      ),
      CommandAction(
        label: 'Refresh VAE',
        hint: 'Re-fetch everything from the API',
        icon: Icons.refresh_outlined,
        run: () {
          widget.state.load();
          widget.sound.tap();
        },
      ),
      CommandAction(
        label:
            widget.darkMode ? 'Switch to light theme' : 'Switch to dark theme',
        hint: 'Animated theme wipe',
        icon: widget.darkMode
            ? Icons.light_mode_outlined
            : Icons.dark_mode_outlined,
        run: _toggleThemeWithWipe,
      ),
      CommandAction(
        label: widget.sound.enabled
            ? 'Mute feedback sounds'
            : 'Unmute feedback sounds',
        hint: 'Ambient chime on create and approve',
        icon: widget.sound.enabled
            ? Icons.volume_up_outlined
            : Icons.volume_off_outlined,
        run: () => widget.sound.toggle(),
      ),
      CommandAction(
        label: 'Replay the tour',
        hint: 'Show the three-step walkthrough again',
        icon: Icons.school_outlined,
        run: () async {
          await resetTour();
          _tourChecked = false;
          await _maybeShowTour();
        },
      ),
      CommandAction(
        label: 'Sign out',
        hint: 'Clear the stored access token',
        icon: Icons.logout_outlined,
        run: () => widget.state.signOut(),
      ),
    ]);
  }

  void _openProfile() {
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => VaeProfileSheet(
            state: widget.state,
            onTheme: widget.onToggleTheme,
            onSignOut: _confirmSignOut));
  }

  void _go(int next) {
    HapticFeedback.selectionClick();
    setState(() => index = next);
  }

  Future<void> _confirmSignOut() async {
    widget.sound.tap();
    final confirmed = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Sign out',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, _, __) => AlertDialog(
        title: const Text('Sign out of VAE?'),
        content: const Text(
            'Your account is safe. You can sign back in at any time.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.logout_outlined),
            label: const Text('Sign out'),
          ),
        ],
      ),
      transitionBuilder: (context, animation, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        child: ScaleTransition(
          scale: Tween<double>(begin: .96, end: 1).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      ),
    );
    if (confirmed == true && mounted) await widget.state.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final pages = [
      OverviewScreen(state: widget.state, onNavigate: _go),
      MediaScreen(state: widget.state, onPublish: () => _go(2)),
      ScheduleScreen(state: widget.state),
      AnalyticsScreen(state: widget.state),
    ];
    const icons = [
      Icons.space_dashboard_outlined,
      Icons.auto_awesome_outlined,
      Icons.schedule_outlined,
      Icons.insights_outlined
    ];
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
          child: Column(children: [
        _TopBar(
            title: _titles[index],
            state: widget.state,
            sound: widget.sound,
            darkMode: widget.darkMode,
            themeButtonKey: _themeButtonKey,
            onToggleTheme: _toggleThemeWithWipe,
            onOpenPalette: _openCommandPalette,
            onSignOut: _confirmSignOut),
        if (widget.state.loading) const LinearProgressIndicator(minHeight: 2),
        if (widget.state.error != null)
          Padding(
              padding: const EdgeInsets.all(12),
              child: Semantics(
                  liveRegion: true,
                  child: Text(widget.state.error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)))),
        Expanded(
            child: Row(children: [
          if (wide)
            NavigationRail(
                selectedIndex: index,
                onDestinationSelected: _go,
                labelType: NavigationRailLabelType.all,
                destinations: [
                  for (var i = 0; i < 4; i++)
                    NavigationRailDestination(
                        icon: Icon(icons[i]), label: Text(_titles[i]))
                ]),
          Expanded(
              child: AnimatedSwitcher(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 260),
            child: KeyedSubtree(key: ValueKey(index), child: pages[index]),
          )),
        ])),
      ])),
      bottomNavigationBar:
          wide ? null : VaeBottomNav(index: index, onSelected: _go),
    );
  }

  static const _titles = ['Home', 'Create', 'Publish', 'Analytics'];
}

/// Custom glass top bar — the mobile equivalent of the web app's `.topbar`.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.state,
    required this.sound,
    required this.darkMode,
    required this.themeButtonKey,
    required this.onToggleTheme,
    required this.onOpenPalette,
    required this.onSignOut,
  });

  final String title;
  final AppState state;
  final AevraSound sound;
  final bool darkMode;
  final GlobalKey themeButtonKey;
  final VoidCallback onToggleTheme;
  final VoidCallback onOpenPalette;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    // A rule under the bar rather than a filled surface: the shader
    // background is the app's main visual asset, and a second opaque strip
    // above the content would cut it off at the top of every screen.
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AevraColors.line)),
      ),
      padding: const EdgeInsets.fromLTRB(AevraSpace.lg, 10, AevraSpace.xs, 10),
      child: Row(
        children: [
          const AevraMark(size: 25),
          const SizedBox(width: AevraSpace.sm),
          Flexible(
            child: Text(
              title.toUpperCase(),
              overflow: TextOverflow.ellipsis,
              style: AevraType.eyebrow(
                  color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
          const Spacer(),
          // #6 — the AI orb now reflects real request state instead of
          // idling forever: it spins while the workspace is loading.
          AnimatedBuilder(
            animation: state,
            builder: (context, _) => AiOrb(
              size: 24,
              state: state.loading ? AiOrbState.thinking : AiOrbState.idle,
            ),
          ),
          const SizedBox(width: AevraSpace.xxs),
          IconButton(
            tooltip: 'Commands',
            onPressed: onOpenPalette,
            icon: const Icon(Icons.search_rounded, size: 20),
            color: AevraColors.muted,
          ),
          IconButton(
            key: themeButtonKey,
            tooltip: darkMode ? 'Use light theme' : 'Use dark theme',
            onPressed: onToggleTheme,
            icon: Icon(
                darkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                size: 20),
            color: AevraColors.muted,
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: onSignOut,
            icon: const Icon(Icons.logout_outlined, size: 20),
            color: AevraColors.muted,
          ),
        ],
      ),
    );
  }
}
