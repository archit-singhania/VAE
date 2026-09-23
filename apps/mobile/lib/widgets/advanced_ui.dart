import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/aevra_theme.dart';
import 'aevra_logo.dart';

/// ---------------------------------------------------------------------
/// Motion policy. Every animated widget in this file routes through here
/// so a single OS-level "reduce motion" setting disables the lot, the same
/// way `prefers-reduced-motion` does on web.
/// ---------------------------------------------------------------------
bool reduceMotion(BuildContext context) =>
    MediaQuery.maybeOf(context)?.disableAnimations ?? false;

/// ---------------------------------------------------------------------
/// #4 — Skeleton shimmer. Mirrors web's `.live-skeleton` gradient sweep.
/// ---------------------------------------------------------------------
class ShimmerBox extends StatefulWidget {
  const ShimmerBox(
      {super.key,
      this.width = double.infinity,
      this.height = 12,
      this.radius = 6});

  final double width;
  final double height;
  final double radius;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1 + t * 3, 0),
              end: Alignment(0 + t * 3, 0),
              colors: const [
                AevraColors.line,
                AevraColors.lineStrong,
                AevraColors.line
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Stat-card-shaped placeholder (icon / label / big number).
class ShimmerStatCard extends StatelessWidget {
  const ShimmerStatCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: const [
        ShimmerBox(width: 18, height: 18, radius: 5),
        SizedBox(height: 10),
        ShimmerBox(width: 60, height: 9),
        SizedBox(height: 8),
        ShimmerBox(width: 40, height: 22),
      ],
    );
  }
}

/// Row-shaped placeholder, for list screens (campaigns / schedule).
class ShimmerRow extends StatelessWidget {
  const ShimmerRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShimmerBox(width: 160, height: 11),
              SizedBox(height: 7),
              ShimmerBox(width: 90, height: 8),
            ],
          ),
        ),
        SizedBox(width: 12),
        ShimmerBox(width: 58, height: 18, radius: 999),
      ],
    );
  }
}

/// A stack of [ShimmerRow]s wrapped in card padding — drop-in replacement
/// for the bare `CircularProgressIndicator` each screen used to show.
class ShimmerList extends StatelessWidget {
  const ShimmerList({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < count; i++) ...[
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 12), child: ShimmerRow()),
          if (i != count - 1) const Divider(height: 1, color: AevraColors.line),
        ],
      ],
    );
  }
}

/// ---------------------------------------------------------------------
/// #6 — AI orb with idle / thinking / success states, shared across screens.
/// ---------------------------------------------------------------------
enum AiOrbState { idle, thinking, success }

class AiOrb extends StatefulWidget {
  const AiOrb({super.key, this.state = AiOrbState.idle, this.size = 42});

  final AiOrbState state;
  final double size;

  @override
  State<AiOrb> createState() => _AiOrbState();
}

class _AiOrbState extends State<AiOrb> with TickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2200));
  late final AnimationController _spin = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant AiOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) _sync();
  }

  void _sync() {
    if (reduceMotion(context)) {
      _pulse.stop();
      _spin.stop();
      return;
    }
    if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    if (widget.state == AiOrbState.thinking) {
      if (!_spin.isAnimating) _spin.repeat();
    } else {
      _spin.stop();
      _spin.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = switch (widget.state) {
      AiOrbState.success => AevraColors.jade,
      AiOrbState.thinking => AevraColors.accent,
      AiOrbState.idle => AevraColors.accent,
    };
    final icon = switch (widget.state) {
      AiOrbState.thinking => Icons.autorenew_rounded,
      AiOrbState.success => Icons.check_rounded,
      AiOrbState.idle => Icons.auto_awesome,
    };
    return AnimatedBuilder(
      animation: Listenable.merge([_pulse, _spin]),
      builder: (context, _) {
        final pulseValue =
            widget.state == AiOrbState.thinking ? 1.0 : _pulse.value;
        return Transform.rotate(
          angle: _spin.value * math.pi * 2,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.09 + pulseValue * 0.07),
              border: Border.all(color: color.withValues(alpha: 0.32)),
              // The orb is the one element in the app allowed a real glow —
              // everything else is restrained specifically so this reads as
              // the single live thing on screen.
              boxShadow: [
                BoxShadow(
                    color: color.withValues(alpha: 0.20),
                    blurRadius: 22 + pulseValue * 10),
              ],
            ),
            child: Icon(icon, size: widget.size * 0.42, color: color),
          ),
        );
      },
    );
  }
}

/// ---------------------------------------------------------------------
/// #7 — Scroll reveal. Staggered fade + rise on first mount. Avoids a
/// scroll listener entirely (cheaper on mobile than web's
/// IntersectionObserver approach) by keying the delay to list index.
/// ---------------------------------------------------------------------
class Reveal extends StatefulWidget {
  const Reveal(
      {super.key,
      required this.child,
      this.index = 0,
      this.stagger = const Duration(milliseconds: 55)});

  final Widget child;
  final int index;
  final Duration stagger;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 420));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (reduceMotion(context)) {
      _controller.value = 1;
      return;
    }
    // Cap the stagger so long lists don't leave the tail invisible for
    // seconds — anything past the 12th item animates immediately.
    final delay = widget.stagger * math.min(widget.index, 12);
    Future<void>.delayed(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve =
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    return AnimatedBuilder(
      animation: curve,
      builder: (context, child) => Opacity(
        opacity: curve.value.clamp(0.0, 1.0),
        child: Transform.translate(
            offset: Offset(0, (1 - curve.value) * 14), child: child),
      ),
      child: widget.child,
    );
  }
}

/// ---------------------------------------------------------------------
/// #18 — Adaptive glass on scroll. [GlassScope] carries a 0→1 intensity
/// that [GlassCard] reads, matching web's `--glass-alpha`. Wrap a scroll
/// view in [AdaptiveGlassScroll] to drive it.
/// ---------------------------------------------------------------------
class GlassScope extends InheritedWidget {
  const GlassScope(
      {super.key,
      required this.intensity,
      required this.offset,
      required super.child});

  /// 0→1 densification ramp, consumed by glass surfaces.
  final double intensity;

  /// Raw scroll pixels, consumed by parallax layers. Kept separate from
  /// [intensity] because that one saturates after 160px, which would make
  /// parallax freeze the moment the glass finished ramping.
  final double offset;

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GlassScope>()?.intensity ?? 0;

  static double offsetOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GlassScope>()?.offset ?? 0;

  @override
  bool updateShouldNotify(GlassScope oldWidget) =>
      oldWidget.intensity != intensity || oldWidget.offset != offset;
}

class AdaptiveGlassScroll extends StatefulWidget {
  const AdaptiveGlassScroll({super.key, required this.child});

  final Widget child;

  @override
  State<AdaptiveGlassScroll> createState() => _AdaptiveGlassScrollState();
}

class _AdaptiveGlassScrollState extends State<AdaptiveGlassScroll> {
  double _intensity = 0;
  double _offset = 0;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollUpdateNotification>(
      onNotification: (notification) {
        if (notification.depth != 0) return false;
        final pixels = notification.metrics.pixels;
        // Ramps to full over the first 160px of scroll, then holds.
        final next = (pixels / 160).clamp(0.0, 1.0);
        if ((next - _intensity).abs() > 0.02 || (pixels - _offset).abs() > 1) {
          setState(() {
            _intensity = next;
            _offset = pixels;
          });
        }
        return false;
      },
      child: GlassScope(
          intensity: _intensity, offset: _offset, child: widget.child),
    );
  }
}

/// ---------------------------------------------------------------------
/// #3 — Particle trails. A cheap, short-lived burst rather than web's
/// always-on field: particles only exist for ~1.2s after [ParticlePulse.fire]
/// is called, and the ticker stops dead when none are alive.
/// ---------------------------------------------------------------------
class ParticlePulse extends ChangeNotifier {
  int _token = 0;
  int get token => _token;

  void fire() {
    _token++;
    notifyListeners();
  }
}

class ParticleField extends StatefulWidget {
  const ParticleField({super.key, required this.pulse});

  final ParticlePulse pulse;

  @override
  State<ParticleField> createState() => _ParticleFieldState();
}

class _Particle {
  _Particle(this.origin, this.velocity, this.radius, this.color);
  final Offset origin;
  final Offset velocity;
  final double radius;
  final Color color;
}

class _ParticleFieldState extends State<ParticleField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200));
  final _rng = math.Random();
  List<_Particle> _particles = const [];

  @override
  void initState() {
    super.initState();
    widget.pulse.addListener(_onPulse);
  }

  void _onPulse() {
    if (!mounted || reduceMotion(context)) return;
    setState(() {
      _particles = List.generate(22, (_) {
        final angle = _rng.nextDouble() * math.pi * 2;
        final speed = 40 + _rng.nextDouble() * 120;
        return _Particle(
          Offset(0.5 + (_rng.nextDouble() - 0.5) * 0.1,
              0.32 + (_rng.nextDouble() - 0.5) * 0.1),
          Offset(math.cos(angle) * speed, math.sin(angle) * speed - 30),
          1 + _rng.nextDouble() * 2,
          _rng.nextBool() ? AevraColors.accent : AevraColors.frost,
        );
      });
    });
    _controller.forward(from: 0).whenComplete(() {
      if (mounted) setState(() => _particles = const []);
    });
  }

  @override
  void dispose() {
    widget.pulse.removeListener(_onPulse);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_particles.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: _ParticlePainter(_particles, _controller.value),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter(this.particles, this.t);

  final List<_Particle> particles;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final fade = (1 - t);
    for (final p in particles) {
      final start = Offset(p.origin.dx * size.width, p.origin.dy * size.height);
      final pos = start + p.velocity * t;
      final paint = Paint()..color = p.color.withValues(alpha: fade * 0.55);
      canvas.drawCircle(pos, p.radius * fade, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) =>
      old.t != t || old.particles != particles;
}

/// ---------------------------------------------------------------------
/// #16 — Ambient sound. No audio asset ships with the repo, so this uses
/// the platform's own UI sounds plus haptics — audible feedback with zero
/// new dependencies. Swap [AevraSound._play] for a `just_audio` call if a
/// real chime asset is added later.
/// ---------------------------------------------------------------------
const _soundPrefsKey = 'aevra.sound-enabled';

class AevraSound extends ChangeNotifier {
  bool _enabled = true;
  bool get enabled => _enabled;

  Future<void> hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_soundPrefsKey) ?? true;
    notifyListeners();
  }

  Future<void> toggle() async {
    _enabled = !_enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundPrefsKey, _enabled);
    if (_enabled) success();
  }

  void tap() => _play(SystemSoundType.click, HapticFeedback.selectionClick);
  void success() => _play(SystemSoundType.click, HapticFeedback.mediumImpact);
  void alert() => _play(SystemSoundType.alert, HapticFeedback.heavyImpact);

  void _play(SystemSoundType sound, Future<void> Function() haptic) {
    if (!_enabled) return;
    SystemSound.play(sound);
    haptic();
  }
}

/// Ambient services (sound + particle pulse) made available to any screen
/// without threading constructor params through every widget.
class AevraServices extends InheritedWidget {
  const AevraServices(
      {super.key,
      required this.sound,
      required this.pulse,
      required super.child});

  final AevraSound sound;
  final ParticlePulse pulse;

  static AevraServices? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AevraServices>();

  /// Fire the shared "something good happened" feedback: a brass particle
  /// burst plus the ambient chime. Safe to call when neither is mounted.
  static void celebrate(BuildContext context) {
    final services = maybeOf(context);
    services?.pulse.fire();
    services?.sound.success();
  }

  @override
  bool updateShouldNotify(AevraServices oldWidget) =>
      oldWidget.sound != sound || oldWidget.pulse != pulse;
}

/// ---------------------------------------------------------------------
/// #5 — Command palette. Web triggers it with ⌘K; mobile triggers it from
/// a search icon in the top bar. Same action vocabulary either way.
/// ---------------------------------------------------------------------
class CommandAction {
  const CommandAction(
      {required this.label,
      required this.hint,
      required this.icon,
      required this.run});

  final String label;
  final String hint;
  final IconData icon;
  final VoidCallback run;
}

Future<void> showCommandPalette(
    BuildContext context, List<CommandAction> actions) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Command palette',
    barrierColor: Colors.black.withValues(alpha: 0.62),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, _, __) => _CommandPalette(actions: actions),
    transitionBuilder: (context, animation, _, child) {
      final curve =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curve,
        child: Transform.translate(
            offset: Offset(0, (1 - curve.value) * 16), child: child),
      );
    },
  );
}

class _CommandPalette extends StatefulWidget {
  const _CommandPalette({required this.actions});

  final List<CommandAction> actions;

  @override
  State<_CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<_CommandPalette> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final results = q.isEmpty
        ? widget.actions
        : widget.actions
            .where((a) =>
                a.label.toLowerCase().contains(q) ||
                a.hint.toLowerCase().contains(q))
            .toList();

    return Align(
      alignment: const Alignment(0, -0.55),
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: AevraColors.panel.withValues(alpha: 0.97),
              borderRadius: BorderRadius.circular(AevraRadius.lg),
              border: Border.all(color: AevraColors.lineStrong),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  blurRadius: 56,
                  spreadRadius: -8,
                  offset: const Offset(0, 22),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    style:
                        const TextStyle(fontSize: 14, color: AevraColors.text),
                    cursorColor: AevraColors.accent,
                    decoration: const InputDecoration(
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      hintText: 'Type a command…',
                      hintStyle:
                          TextStyle(color: AevraColors.muted2, fontSize: 14),
                      prefixIcon: Icon(Icons.search_rounded,
                          size: 18, color: AevraColors.muted),
                      prefixIconConstraints: BoxConstraints(minWidth: 30),
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
                const Divider(height: 1, color: AevraColors.line),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: results.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 26),
                          child: Text('No matching commands',
                              style: TextStyle(
                                  fontSize: 12, color: AevraColors.muted2)),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          itemCount: results.length,
                          itemBuilder: (context, i) {
                            final action = results[i];
                            return ListTile(
                              dense: true,
                              leading: Icon(action.icon,
                                  size: 18, color: AevraColors.accent),
                              title: Text(action.label,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500)),
                              subtitle: Text(action.hint,
                                  style: const TextStyle(
                                      fontSize: 10, color: AevraColors.muted2)),
                              onTap: () {
                                Navigator.of(context).pop();
                                action.run();
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------
/// #8 — Onboarding tour: 3-step modal, persisted via SharedPreferences.
/// ---------------------------------------------------------------------
const _tourPrefsKey = 'aevra.tour-complete';

Future<bool> hasCompletedTour() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_tourPrefsKey) ?? false;
}

Future<void> markTourComplete() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_tourPrefsKey, true);
}

Future<void> resetTour() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_tourPrefsKey);
}

class OnboardingSheet extends StatefulWidget {
  const OnboardingSheet({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<OnboardingSheet> createState() => _OnboardingSheetState();
}

class _OnboardingStep {
  const _OnboardingStep(this.title, this.body);
  final String title;
  final String body;
}

class _OnboardingSheetState extends State<OnboardingSheet> {
  int step = 0;
  static const _steps = [
    _OnboardingStep(
      'Welcome to VAE',
      'Your home for media, connected channels, and upcoming posts.',
    ),
    _OnboardingStep(
      'Human approval, always',
      'Every generated variant waits for your approval before it can publish anywhere.',
    ),
    _OnboardingStep(
      'Everything in one place',
      'Create, Publish, and Analytics stay in sync with your web workspace.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isLast = step == _steps.length - 1;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AevraColors.panel.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(AevraRadius.xl),
          border: Border.all(color: AevraColors.lineStrong),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 72,
              spreadRadius: -12,
              offset: const Offset(0, 28),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('STEP ${step + 1} / ${_steps.length}',
                    style: AevraType.eyebrow()),
                const Spacer(),
                const AiOrb(size: 34),
              ],
            ),
            const SizedBox(height: AevraSpace.md),
            Text(_steps[step].title, style: AevraType.display(24)),
            const SizedBox(height: AevraSpace.xs),
            Text(
              _steps[step].body,
              style: const TextStyle(
                  fontSize: 13.5, height: 1.55, color: AevraColors.textSoft),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                TextButton(
                  onPressed: () async {
                    await markTourComplete();
                    widget.onDone();
                  },
                  child: const Text('Skip',
                      style: TextStyle(color: AevraColors.muted2)),
                ),
                const Spacer(),
                Row(
                  children: List.generate(
                    _steps.length,
                    (i) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == step
                            ? AevraColors.accent
                            : AevraColors.lineStrong,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () async {
                    if (isLast) {
                      await markTourComplete();
                      widget.onDone();
                    } else {
                      setState(() => step += 1);
                    }
                  },
                  child: Text(isLast ? 'Get started' : 'Next'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------
/// #9 — Animated theme-toggle transition: a brand-marked circular reveal
/// expanding from the toggle button, mirroring web's `.theme-wipe`.
/// ---------------------------------------------------------------------
class ThemeWipeOverlay extends StatefulWidget {
  const ThemeWipeOverlay({
    super.key,
    required this.center,
    required this.toDark,
    required this.onMidpoint,
    required this.onComplete,
  });

  final Offset center;
  final bool toDark;

  /// Fired the instant the circle has covered the screen — flip the app's
  /// theme here so the swap itself is never visible.
  final VoidCallback onMidpoint;
  final VoidCallback onComplete;

  @override
  State<ThemeWipeOverlay> createState() => _ThemeWipeOverlayState();
}

class _ThemeWipeOverlayState extends State<ThemeWipeOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));
  bool _flipped = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      // Phase 1 (0 → 0.5) grows the circle; the moment it covers the screen
      // the theme flips underneath, then phase 2 fades the cover away.
      if (!_flipped && _controller.value >= 0.5) {
        _flipped = true;
        widget.onMidpoint();
      }
    });
    _controller.forward().whenComplete(widget.onComplete);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final maxRadius = size.longestSide * 1.2;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          final grow = (t / 0.5).clamp(0.0, 1.0);
          final fade = t <= 0.5 ? 1.0 : 1 - ((t - 0.5) / 0.5).clamp(0.0, 1.0);
          final radius = Curves.easeOutCubic.transform(grow) * maxRadius;
          return Opacity(
            opacity: fade,
            child: ClipPath(
              clipper:
                  _CircleRevealClipper(center: widget.center, radius: radius),
              child: Container(
                color: widget.toDark ? AevraColors.bg : AevraLightColors.bg,
                child: Center(
                  child: Opacity(
                    opacity: grow.clamp(0.0, 1.0),
                    child: AevraMark(
                      size: 40,
                      color: widget.toDark
                          ? AevraColors.accent
                          : AevraLightColors.accent,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CircleRevealClipper extends CustomClipper<Path> {
  _CircleRevealClipper({required this.center, required this.radius});

  final Offset center;
  final double radius;

  @override
  Path getClip(Size size) =>
      Path()..addOval(Rect.fromCircle(center: center, radius: radius));

  @override
  bool shouldReclip(covariant _CircleRevealClipper oldClipper) =>
      oldClipper.center != center || oldClipper.radius != radius;
}

/// ---------------------------------------------------------------------
/// #10 — Bento drag-reorder persistence helper. The widget side lives in
/// overview_screen.dart; this just stores the order.
/// ---------------------------------------------------------------------
const _bentoPrefsKey = 'aevra.bento-order';

Future<List<int>?> loadBentoOrder(int expectedLength) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getStringList(_bentoPrefsKey);
  if (raw == null || raw.length != expectedLength) return null;
  final parsed = raw.map(int.tryParse).whereType<int>().toList();
  // Reject anything corrupt or not a clean permutation.
  if (parsed.length != expectedLength) return null;
  if (parsed.toSet().length != expectedLength) return null;
  if (parsed.any((i) => i < 0 || i >= expectedLength)) return null;
  return parsed;
}

Future<void> saveBentoOrder(List<int> order) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setStringList(_bentoPrefsKey, order.map((i) => '$i').toList());
}
