import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/analytics_screen.dart';
import 'screens/advanced_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/campaigns_screen.dart';
import 'screens/media_screen.dart';
import 'screens/ml_insights_screen.dart';
import 'screens/overview_screen.dart';
import 'screens/schedule_screen.dart';
import 'state/app_state.dart';
import 'theme/aevra_theme.dart';
import 'widgets/advanced_ui.dart';
import 'widgets/aevra_logo.dart';
import 'widgets/depth.dart';
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
  bool _adminPortal = false;
  bool _lastPortalWasAdmin = false;

  void _syncPortalTheme() {
    final next = state.user?.isAdmin == true;
    if (state.user != null) _lastPortalWasAdmin = next;
    if (next != _adminPortal && mounted) {
      setState(() => _adminPortal = next);
    }
  }

  @override
  void initState() {
    super.initState();
    state = AppState();
    state.addListener(_syncPortalTheme);
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
    state.removeListener(_syncPortalTheme);
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
      theme: _adminPortal
          ? (darkMode ? AevraTheme.adminDark : AevraTheme.adminLight)
          : (darkMode ? AevraTheme.dark : AevraTheme.light),
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
            duration: reduceMotion(context)
                ? Duration.zero
                : const Duration(milliseconds: 420),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity:
                  CurvedAnimation(parent: animation, curve: Curves.easeOut),
              child: ScaleTransition(
                scale: Tween<double>(begin: .988, end: 1).animate(
                  CurvedAnimation(
                      parent: animation, curve: Curves.easeOutCubic),
                ),
                child: child,
              ),
            ),
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
                    initialAdminPortal: _lastPortalWasAdmin,
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
  bool _railCollapsed = false;
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
          icon: LucideIcons.bookOpen,
          run: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => AdvancedScreen(state: widget.state)))),
      if (widget.state.user?.isAdmin == true)
        CommandAction(
            label: 'Admin dashboard',
            hint: 'Admin',
            icon: LucideIcons.shieldCheck,
            run: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) =>
                    AdvancedScreen(state: widget.state, admin: true)))),
      CommandAction(
          label: 'Profile',
          hint: 'Account and appearance',
          icon: LucideIcons.userRound,
          run: _openProfile),
      CommandAction(
        label: 'Go to Home',
        hint: 'Media, channel, and publishing summary',
        icon: LucideIcons.brainCircuit,
        run: () => _go(0),
      ),
      CommandAction(
        label: 'Go to Create',
        hint: 'Create images and captions',
        icon: LucideIcons.sparkles,
        run: () => _go(1),
      ),
      CommandAction(
        label: 'Go to Publish',
        hint: 'Upcoming scheduled posts',
        icon: LucideIcons.calendarDays,
        run: () => _go(2),
      ),
      CommandAction(
        label: 'Go to Analytics',
        hint: 'Publishing and engagement signal',
        icon: LucideIcons.brainCircuit,
        run: () => _go(3),
      ),
      if (widget.state.user?.isAdmin != true)
        CommandAction(
          label: 'ML insights',
          hint: 'Explore recommendations and predictions',
          icon: LucideIcons.sparkles,
          run: () => _go(4),
        ),
      CommandAction(
        label: 'Refresh VAE',
        hint: 'Re-fetch everything from the API',
        icon: LucideIcons.refreshCw,
        run: () {
          widget.state.load();
          widget.sound.tap();
        },
      ),
      CommandAction(
        label:
            widget.darkMode ? 'Switch to light theme' : 'Switch to dark theme',
        hint: 'Animated theme wipe',
        icon: widget.darkMode ? LucideIcons.sun : LucideIcons.moon,
        run: _toggleThemeWithWipe,
      ),
      CommandAction(
        label: widget.sound.enabled
            ? 'Mute feedback sounds'
            : 'Unmute feedback sounds',
        hint: 'Ambient chime on create and approve',
        icon: widget.sound.enabled ? LucideIcons.volume2 : LucideIcons.volumeX,
        run: () => widget.sound.toggle(),
      ),
      CommandAction(
        label: 'Replay the tour',
        hint: 'Show the three-step walkthrough again',
        icon: LucideIcons.graduationCap,
        run: () async {
          await resetTour();
          _tourChecked = false;
          await _maybeShowTour();
        },
      ),
      CommandAction(
        label: 'Sign out',
        hint: 'Clear the stored access token',
        icon: LucideIcons.logOut,
        run: () => widget.state.signOut(),
      ),
    ]);
  }

  void _openProfile() {
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        barrierColor: Colors.black.withValues(alpha: .32),
        constraints: const BoxConstraints(maxWidth: 600),
        sheetAnimationStyle: AnimationStyle(
          duration: reduceMotion(context)
              ? Duration.zero
              : const Duration(milliseconds: 400),
          reverseDuration: reduceMotion(context)
              ? Duration.zero
              : const Duration(milliseconds: 300),
        ),
        builder: (context) =>
            VaeProfileSheet(state: widget.state, onSignOut: _confirmSignOut));
  }

  void _openCampaigns() {
    widget.sound.tap();
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => CampaignsScreen(state: widget.state)));
  }

  void _go(int next) {
    if (next == index) return;
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
      transitionDuration: reduceMotion(context)
          ? Duration.zero
          : const Duration(milliseconds: 260),
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
            icon: const Icon(LucideIcons.logOut),
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
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final admin = widget.state.user?.isAdmin == true;
    final pages = admin
        ? [
            AdvancedScreen(
                state: widget.state, admin: true, adminSection: 'overview'),
            AdvancedScreen(
                state: widget.state, admin: true, adminSection: 'media'),
            AdvancedScreen(
                state: widget.state, admin: true, adminSection: 'publishing'),
            AdvancedScreen(
                state: widget.state, admin: true, adminSection: 'analytics'),
            AdvancedScreen(
                state: widget.state, admin: true, adminSection: 'payments'),
          ]
        : [
            OverviewScreen(
                state: widget.state,
                onNavigate: _go,
                onCampaigns: _openCampaigns),
            MediaScreen(state: widget.state, onPublish: () => _go(2)),
            ScheduleScreen(state: widget.state),
            AnalyticsScreen(state: widget.state),
            MlInsightsScreen(state: widget.state),
          ];
    final titles = admin
        ? const [
            'Home',
            'AI usage',
            'Publishing',
            'Analytics',
            'Payment review'
          ]
        : const ['Home', 'Create', 'Publish', 'Analytics', 'ML insights'];
    final icons = [
      LucideIcons.layoutDashboard,
      LucideIcons.sparkles,
      LucideIcons.calendarDays,
      LucideIcons.chartNoAxesCombined,
      admin ? LucideIcons.shieldCheck : LucideIcons.sparkles,
    ];
    final shellTheme = admin
        ? (widget.darkMode ? AevraTheme.adminDark : AevraTheme.adminLight)
        : Theme.of(context);
    return Theme(
      data: shellTheme,
      child: Scaffold(
        backgroundColor: shellTheme.scaffoldBackgroundColor,
        body: Stack(children: [
          Positioned.fill(child: RepaintBoundary(child: _WorkspaceBackdrop())),
          SafeArea(
              child: Column(children: [
            _TopBar(
                title: titles[index],
                state: widget.state,
                sound: widget.sound,
                wide: wide,
                darkMode: widget.darkMode,
                themeButtonKey: _themeButtonKey,
                onToggleTheme: _toggleThemeWithWipe,
                onRefresh: () => widget.state.load(),
                onPrimaryAction: () => _go(admin ? 4 : 1),
                onOpenPalette: _openCommandPalette,
                onOpenProfile: _openProfile),
            if (widget.state.loading)
              const LinearProgressIndicator(minHeight: 2),
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
                _WorkspaceRail(
                  index: index,
                  titles: titles,
                  icons: icons,
                  admin: admin,
                  collapsed: _railCollapsed ||
                      MediaQuery.textScalerOf(context).scale(14) > 20,
                  onCollapse: () =>
                      setState(() => _railCollapsed = !_railCollapsed),
                  onSelected: _go,
                  onCommands: _openCommandPalette,
                  onProfile: _openProfile,
                ),
              Expanded(
                  child: AnimatedSwitcher(
                duration: reduceMotion(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 320),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, .014),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(key: ValueKey(index), child: pages[index]),
              )),
            ])),
          ])),
        ]),
        bottomNavigationBar: wide
            ? null
            : VaeBottomNav(
                index: index,
                onSelected: _go,
                onProfile: _openProfile,
                avatarUrl: widget.state.user?.avatarUrl,
                admin: admin),
      ),
    );
  }
}

/// A quiet canvas keeps the working screens readable and avoids running the
/// landing page's animated shader behind lists, charts and form controls.
class _WorkspaceBackdrop extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(color: theme.scaffoldBackgroundColor),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(.8, -1),
            radius: 1.35,
            colors: [
              theme.colorScheme.primary.withValues(
                  alpha: theme.brightness == Brightness.dark ? .065 : .035),
              Colors.transparent,
            ],
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// One floating control plane keeps the chrome separate from page content.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.state,
    required this.sound,
    required this.wide,
    required this.darkMode,
    required this.themeButtonKey,
    required this.onToggleTheme,
    required this.onRefresh,
    required this.onPrimaryAction,
    required this.onOpenPalette,
    required this.onOpenProfile,
  });

  final String title;
  final AppState state;
  final AevraSound sound;
  final bool wide, darkMode;
  final GlobalKey themeButtonKey;
  final VoidCallback onToggleTheme, onRefresh, onPrimaryAction;
  final VoidCallback onOpenPalette, onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final admin = state.user?.isAdmin == true;
    final compact = MediaQuery.sizeOf(context).width < 380 ||
        MediaQuery.textScalerOf(context).scale(14) > 19;
    Widget control(String tooltip, IconData icon, VoidCallback action,
            {Key? key}) =>
        IconButton(
          key: key,
          tooltip: tooltip,
          onPressed: action,
          icon: Icon(icon, size: 19),
          style: IconButton.styleFrom(
            minimumSize: const Size(44, 44),
            backgroundColor: colors.onSurface.withValues(alpha: .045),
          ),
        );
    return Padding(
      padding: EdgeInsets.fromLTRB(wide ? 16 : 12, 8, wide ? 16 : 12, 8),
      child: GlassChrome(
        radius: 30,
        padding: EdgeInsets.fromLTRB(wide ? 20 : 14, 10, 10, 10),
        child: Row(children: [
          Expanded(
            child: wide
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(admin ? 'Administration' : 'Your workspace',
                          style: theme.textTheme.bodySmall),
                      const SizedBox(height: 3),
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (compact)
                        AevraMark(size: 30, admin: admin)
                      else
                        AevraWordmark(markSize: 28, fontSize: 21, admin: admin),
                      if (!compact) ...[
                        const SizedBox(height: 6),
                        Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(fontSize: 10.5)),
                      ],
                    ],
                  ),
          ),
          const SizedBox(width: 8),
          control('Commands', LucideIcons.search, onOpenPalette),
          const SizedBox(width: 6),
          if (wide) ...[
            control('Refresh workspace', LucideIcons.refreshCw, onRefresh),
            const SizedBox(width: 6),
          ],
          control(darkMode ? 'Use light theme' : 'Use dark theme',
              darkMode ? LucideIcons.sun : LucideIcons.moon, onToggleTheme,
              key: themeButtonKey),
          if (wide) ...[
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: onPrimaryAction,
              icon: Icon(admin ? LucideIcons.shieldCheck : LucideIcons.plus,
                  size: 17),
              label: Text(admin ? 'Review payments' : 'Create'),
            ),
          ],
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Open profile',
            onPressed: onOpenProfile,
            style: IconButton.styleFrom(
              minimumSize: const Size(44, 44),
              backgroundColor: colors.primary.withValues(alpha: .12),
            ),
            icon: state.user?.avatarUrl == null
                ? Icon(LucideIcons.userRound, size: 18, color: colors.primary)
                : ClipOval(
                    child: Image.network(state.user!.avatarUrl!,
                        width: 26,
                        height: 26,
                        fit: BoxFit.cover,
                        errorBuilder: (_, error, stack) => Icon(
                            LucideIcons.userRound,
                            size: 18,
                            color: colors.primary)),
                  ),
          ),
        ]),
      ),
    );
  }
}

class _WorkspaceRail extends StatelessWidget {
  const _WorkspaceRail({
    required this.index,
    required this.titles,
    required this.icons,
    required this.admin,
    required this.collapsed,
    required this.onCollapse,
    required this.onSelected,
    required this.onCommands,
    required this.onProfile,
  });

  final int index;
  final List<String> titles;
  final List<IconData> icons;
  final bool admin, collapsed;
  final VoidCallback onCollapse, onCommands, onProfile;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    Widget item(String title, IconData icon, VoidCallback action,
        {bool selected = false}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Semantics(
          selected: selected,
          button: true,
          child: Tooltip(
            message: title,
            child: InkWell(
              onTap: action,
              borderRadius: BorderRadius.circular(24),
              child: AnimatedContainer(
                duration: reduceMotion(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                constraints: const BoxConstraints(minHeight: 48),
                padding: EdgeInsets.symmetric(horizontal: collapsed ? 8 : 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: selected
                      ? colors.primary.withValues(alpha: .14)
                      : Colors.transparent,
                  border: Border.all(
                      color: selected
                          ? colors.primary.withValues(alpha: .18)
                          : Colors.transparent),
                ),
                child: Row(
                  mainAxisAlignment: collapsed
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.start,
                  children: [
                    Icon(icon,
                        size: 20,
                        color: selected
                            ? colors.primary
                            : colors.onSurfaceVariant),
                    if (!collapsed) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: selected
                                  ? colors.onSurface
                                  : colors.onSurfaceVariant,
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w500,
                            )),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 0, 16),
      child: SizedBox(
        width: collapsed ? 84 : 224,
        child: GlassChrome(
          radius: 32,
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
              child: collapsed
                  ? AevraMark(size: 34, admin: admin)
                  : AevraWordmark(markSize: 34, fontSize: 25, admin: admin),
            ),
            for (var i = 0; i < titles.length; i++)
              item(titles[i], icons[i], () => onSelected(i),
                  selected: index == i),
            const Spacer(),
            Divider(color: theme.dividerColor),
            const SizedBox(height: 12),
            item('Commands', LucideIcons.search, onCommands),
            item('Profile', LucideIcons.userRound, onProfile),
            item(
                collapsed ? 'Expand sidebar' : 'Collapse sidebar',
                collapsed
                    ? LucideIcons.panelLeftOpen
                    : LucideIcons.panelLeftClose,
                onCollapse),
          ]),
        ),
      ),
    );
  }
}
