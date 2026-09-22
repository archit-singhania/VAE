import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../state/app_state.dart';
import '../theme/aevra_theme.dart';
import '../widgets/advanced_ui.dart';
import '../widgets/depth.dart';
import '../widgets/glass_card.dart';

/// Mobile counterpart of the web app's overview view.
class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key, required this.state});

  final AppState state;

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

/// One tile of the bento grid. Values are resolved at build time from
/// [AppState], so reordering only moves the definition, never the data.
class _StatSpec {
  const _StatSpec(
      this.id, this.label, this.caption, this.icon, this.color, this.read);

  final String id;
  final String label;
  final String caption;
  final IconData icon;
  final Color color;
  final int Function(AppState) read;
}

class _OverviewScreenState extends State<OverviewScreen> {
  static final List<_StatSpec> _specs = [
    _StatSpec('brain', 'Knowledge base', 'indexed sources', Icons.hub_outlined,
        AevraColors.frost, (s) => s.documents.length),
    _StatSpec(
        'campaigns',
        'Campaigns',
        'in workspace',
        Icons.auto_awesome_outlined,
        AevraColors.accent,
        (s) => s.campaigns.length),
    // Amber, not the accent: this is the one tile that means "a human still
    // owes this a decision", and it should not be the same colour as the
    // tiles that are merely counting things.
    _StatSpec(
        'queue',
        'Approval queue',
        'awaiting you',
        Icons.how_to_reg_outlined,
        AevraColors.amber,
        (s) =>
            s.campaigns.where((c) => c.status == 'awaiting_approval').length),
    _StatSpec('media', 'Media assets', 'generated assets', Icons.image_outlined,
        AevraColors.jade, (s) => s.assets.length),
  ];

  /// #10 — persisted bento order (indexes into [_specs]).
  List<int> _order = List<int>.generate(_specs.length, (i) => i);

  @override
  void initState() {
    super.initState();
    loadBentoOrder(_specs.length).then((saved) {
      if (saved != null && mounted) setState(() => _order = saved);
    });
  }

  /// Passed to `onReorderItem`, whose `newIndex` is already corrected for the
  /// removal of the dragged item. The old `onReorder` callback was not, which
  /// is why the previous version had to subtract one by hand — doing that
  /// here as well would drop every downward drag one slot short.
  void _reorder(int oldIndex, int newIndex) {
    HapticFeedback.mediumImpact();
    setState(() {
      final moved = _order.removeAt(oldIndex);
      _order.insert(newIndex, moved);
    });
    saveBentoOrder(_order);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final firstName =
            (state.user?.displayName ?? '').split(' ').firstOrNull ?? 'there';
        final firstLoad =
            state.loading && state.campaigns.isEmpty && state.documents.isEmpty;

        // #18 — adaptive glass: every GlassCard below reads scroll intensity
        // from this scope and densifies as the user scrolls.
        return AdaptiveGlassScroll(
          child: RefreshIndicator(
            onRefresh: state.load,
            color: AevraColors.accent,
            backgroundColor: AevraColors.panel,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(AevraSpace.gutter,
                  AevraSpace.md, AevraSpace.gutter, AevraSpace.xxl),
              children: [
                ParallaxLayer(
                  depth: -1.6,
                  child: Reveal(
                    index: 0,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('CONTROL ROOM', style: AevraType.eyebrow()),
                              const SizedBox(height: AevraSpace.sm),
                              Text(
                                'Good to see you,\n$firstName.',
                                style: AevraType.display(32),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AevraSpace.sm),
                        // #6 — shared orb, now state-aware.
                        AiOrb(
                            state: state.loading
                                ? AiOrbState.thinking
                                : AiOrbState.idle),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AevraSpace.sm),
                ParallaxLayer(
                  depth: -1.1,
                  child: const Reveal(
                    index: 1,
                    child: Text(
                      'Everything below is live from the workspace. Nothing publishes without you.',
                      style: TextStyle(
                          fontSize: 13.5,
                          height: 1.55,
                          color: AevraColors.textSoft),
                    ),
                  ),
                ),
                const SizedBox(height: AevraSpace.xl),
                if (firstLoad)
                  // #4 — skeleton shimmer instead of a bare spinner.
                  Column(
                    children: List.generate(
                      2,
                      (i) => const Padding(
                        padding: EdgeInsets.only(bottom: AevraSpace.sm),
                        child: Row(
                          children: [
                            Expanded(
                                child: GlassCard(child: ShimmerStatCard())),
                            SizedBox(width: AevraSpace.sm),
                            Expanded(
                                child: GlassCard(child: ShimmerStatCard())),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  _bento(state),
                const SizedBox(height: AevraSpace.md),
                Reveal(
                  index: 6,
                  child: GlassSurface(
                    elevation: GlassElevation.floating,
                    padding: const EdgeInsets.fromLTRB(AevraSpace.md,
                        AevraSpace.md, AevraSpace.md, AevraSpace.xs),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('RECENT WORK',
                                style: AevraType.eyebrow(
                                    color: AevraColors.muted)),
                            const Spacer(),
                            Text('${state.campaigns.length}',
                                style: AevraType.mono()),
                          ],
                        ),
                        if (firstLoad) ...[
                          const SizedBox(height: AevraSpace.sm),
                          const ShimmerList(count: 3),
                        ] else if (state.campaigns.isEmpty) ...[
                          const SizedBox(height: AevraSpace.sm),
                          const Text(
                            'Your campaign runway is clear. Create one from the Campaigns tab.',
                            style: TextStyle(
                                fontSize: 12,
                                height: 1.5,
                                color: AevraColors.muted2),
                          ),
                          const SizedBox(height: AevraSpace.xs),
                        ] else
                          for (final c in state.campaigns.take(4))
                            Padding(
                              padding:
                                  const EdgeInsets.only(top: AevraSpace.sm),
                              child: Row(
                                children: [
                                  Container(
                                    width: 2,
                                    height: 22,
                                    margin: const EdgeInsets.only(
                                        right: AevraSpace.sm),
                                    decoration: BoxDecoration(
                                      color: _statusTint(c.status),
                                      borderRadius: BorderRadius.circular(
                                          AevraRadius.pill),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      c.name,
                                      style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: AevraSpace.xs),
                                  Text(
                                    c.status.replaceAll('_', ' '),
                                    style: AevraType.mono(
                                        size: 9, color: _statusTint(c.status)),
                                  ),
                                ],
                              ),
                            ),
                        const SizedBox(height: AevraSpace.xs),
                      ],
                    ),
                  ),
                ),
                if (state.error != null) ...[
                  const SizedBox(height: AevraSpace.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AevraSpace.sm, vertical: 10),
                    decoration: BoxDecoration(
                      color: AevraColors.rose.withValues(alpha: 0.09),
                      border: Border.all(
                          color: AevraColors.rose.withValues(alpha: 0.22)),
                      borderRadius: BorderRadius.circular(AevraRadius.sm),
                    ),
                    child: Text(
                      state.error!,
                      style: const TextStyle(
                          fontSize: 11.5,
                          height: 1.45,
                          color: AevraColors.rose),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// #10 — long-press any tile to drag it; the order persists across launches.
  Widget _bento(AppState state) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      padding: EdgeInsets.zero,
      itemCount: _order.length,
      onReorderItem: _reorder,
      proxyDecorator: (child, index, animation) => Material(
        color: Colors.transparent,
        child: Transform.scale(scale: 1.03, child: child),
      ),
      itemBuilder: (context, position) {
        final spec = _specs[_order[position]];
        return ReorderableDelayedDragStartListener(
          key: ValueKey(spec.id),
          index: position,
          child: Padding(
            padding: const EdgeInsets.only(bottom: AevraSpace.sm),
            child: Reveal(
                index: 2 + position, child: _tile(spec, spec.read(state))),
          ),
        );
      },
    );
  }

  Widget _tile(_StatSpec spec, int value) {
    // Tilt is tap-driven only (enablePan stays false): these tiles also host
    // ReorderableListView's long-press drag, and a pan-tilt would contend
    // with it in the gesture arena.
    return DepthCard(
      elevation: GlassElevation.floating,
      padding: const EdgeInsets.fromLTRB(
          AevraSpace.md, AevraSpace.md, AevraSpace.sm, AevraSpace.md),
      child: Row(
        children: [
          // A squircle chip rather than a circle: circles read as avatars,
          // and these are categories, not people.
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AevraRadius.sm),
              color: spec.color.withValues(alpha: 0.10),
              border: Border.all(color: spec.color.withValues(alpha: 0.20)),
            ),
            child: Icon(spec.icon, size: 17, color: spec.color),
          ),
          const SizedBox(width: AevraSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  spec.label,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AevraColors.text,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(spec.caption, style: AevraType.mono(size: 9.5)),
              ],
            ),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.toDouble()),
            duration: const Duration(milliseconds: 720),
            curve: Curves.easeOutCubic,
            builder: (context, animated, _) => Text(
              animated.round().toString(),
              // Tabular figures: without them a counter ticking 8 → 9 → 10
              // reflows the whole row as the glyph widths change.
              style: AevraType.metric(30, color: spec.color),
            ),
          ),
          const SizedBox(width: AevraSpace.xs),
          const Icon(Icons.drag_indicator_rounded,
              size: 15, color: AevraColors.muted2),
        ],
      ),
    );
  }

  /// Shared status tint, so a campaign's colour is the same on the overview
  /// as it is in the campaigns list.
  static Color _statusTint(String status) => switch (status) {
        'approved' || 'ready' || 'published' => AevraColors.jade,
        'awaiting_approval' => AevraColors.amber,
        'failed' || 'rejected' => AevraColors.rose,
        _ => AevraColors.muted2,
      };
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
