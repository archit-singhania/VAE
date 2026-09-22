import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../theme/aevra_theme.dart';
import '../widgets/advanced_ui.dart';
import '../widgets/depth.dart';
import '../widgets/glass_card.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final campaigns = state.campaigns;
        final approved = campaigns
            .where((c) => c.status == 'approved' || c.status == 'published')
            .length;
        final approvalRate = campaigns.isEmpty
            ? 0
            : ((approved / campaigns.length) * 100).round();
        final connected =
            state.accounts.where((a) => a.status == 'connected').length;

        final firstLoad = state.loading && campaigns.isEmpty;

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
                  depth: -1.4,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('SIGNAL', style: AevraType.eyebrow()),
                            const SizedBox(height: AevraSpace.xs),
                            Text('Analytics', style: AevraType.display(30)),
                            const SizedBox(height: AevraSpace.xxs),
                            const Text(
                              'Measured across this workspace only.',
                              style: TextStyle(
                                  fontSize: 12, color: AevraColors.muted),
                            ),
                          ],
                        ),
                      ),
                      AiOrb(
                          size: 32,
                          state: state.loading
                              ? AiOrbState.thinking
                              : AiOrbState.idle),
                    ],
                  ),
                ),
                const SizedBox(height: AevraSpace.lg),
                if (firstLoad) ...[
                  const Row(
                    children: [
                      Expanded(child: GlassCard(child: ShimmerStatCard())),
                      SizedBox(width: AevraSpace.sm),
                      Expanded(child: GlassCard(child: ShimmerStatCard())),
                    ],
                  ),
                  const SizedBox(height: AevraSpace.sm),
                  const GlassCard(child: ShimmerList(count: 3)),
                ] else ...[
                  Reveal(
                    index: 0,
                    child: Row(
                      children: [
                        Expanded(
                            child: _stat(
                                'Approval rate',
                                '$approvalRate%',
                                AevraColors.accent,
                                '$approved of ${campaigns.length} cleared')),
                        const SizedBox(width: AevraSpace.sm),
                        Expanded(
                            child: _stat('Connected', '$connected',
                                AevraColors.jade, 'publishing destinations')),
                      ],
                    ),
                  ),
                  const SizedBox(height: AevraSpace.sm),
                  Reveal(
                    index: 1,
                    child: DepthCard(
                      elevation: GlassElevation.floating,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('CAMPAIGN MIX',
                              style:
                                  AevraType.eyebrow(color: AevraColors.muted)),
                          const SizedBox(height: AevraSpace.sm),
                          Text(
                            '${state.campaigns.length} campaigns · ${state.assets.length} media assets · '
                            '${state.documents.length} indexed sources',
                            style: const TextStyle(
                                fontSize: 12.5,
                                color: AevraColors.textSoft,
                                height: 1.55),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AevraSpace.sm),
                  Reveal(
                    index: 2,
                    child: DepthCard(
                      elevation: GlassElevation.floating,
                      child: _AnimatedBars(
                        values: [
                          campaigns.length.toDouble(),
                          approved.toDouble(),
                          state.assets.length.toDouble(),
                          state.documents.length.toDouble(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AevraSpace.sm),
                  Reveal(
                    index: 3,
                    child: GlassSurface(
                      elevation: GlassElevation.flat,
                      padding: const EdgeInsets.symmetric(
                          horizontal: AevraSpace.md, vertical: AevraSpace.sm),
                      child: Row(
                        children: [
                          // A live dot rather than a tick: this is a connection
                          // state, and a tick reads as a completed action.
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: state.loading
                                  ? AevraColors.amber
                                  : AevraColors.jade,
                            ),
                          ),
                          const SizedBox(width: AevraSpace.sm),
                          Expanded(
                            child: Text(
                              state.loading
                                  ? 'SYNCING WORKSPACE'
                                  : 'SYNCED WITH LIVE WORKSPACE',
                              style: AevraType.eyebrow(
                                color: state.loading
                                    ? AevraColors.amber
                                    : AevraColors.jade,
                              ),
                            ),
                          ),
                        ],
                      ),
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

  Widget _stat(String label, String value, Color color, String caption) {
    return DepthCard(
      elevation: GlassElevation.floating,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: AevraType.eyebrow(color: AevraColors.muted)),
          const SizedBox(height: AevraSpace.sm),
          Text(value, style: AevraType.metric(34, color: color)),
          const SizedBox(height: AevraSpace.xs),
          Text(caption, style: AevraType.mono(size: 9.5)),
        ],
      ),
    );
  }
}

class _AnimatedBars extends StatelessWidget {
  const _AnimatedBars({required this.values});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    final maxValue =
        values.fold<double>(1, (max, value) => value > max ? value : max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SIGNAL ACTIVITY',
            style: AevraType.eyebrow(color: AevraColors.muted)),
        const SizedBox(height: AevraSpace.md),
        SizedBox(
          height: 84,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(values.length, (i) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: TweenAnimationBuilder<double>(
                    // Staggered so the four bars grow in sequence rather than
                    // as one block, which reads as four separate measurements.
                    tween: Tween(begin: 0, end: values[i] / maxValue),
                    duration: Duration(milliseconds: 700 + i * 90),
                    curve: Curves.easeOutCubic,
                    builder: (context, progress, _) => Container(
                      height: 76 * progress + 3,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AevraRadius.xs),
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            AevraColors.frost.withValues(alpha: 0.28),
                            AevraColors.frost,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: AevraSpace.sm),
        Row(
          children: [
            for (final label in ['CAMPAIGNS', 'APPROVED', 'MEDIA', 'SOURCES'])
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: AevraType.mono(size: 8),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
