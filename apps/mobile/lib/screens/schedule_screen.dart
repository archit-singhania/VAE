import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../theme/aevra_theme.dart';
import '../widgets/advanced_ui.dart';
import '../widgets/depth.dart';
import '../widgets/glass_card.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key, required this.state});

  final AppState state;

  String _formatTime(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '—';
    final local = dt.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDay(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[dt.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final scheduled = state.scheduled;
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
                            Text('UPCOMING', style: AevraType.eyebrow()),
                            const SizedBox(height: AevraSpace.xs),
                            Text('Schedule', style: AevraType.display(30)),
                            const SizedBox(height: AevraSpace.xxs),
                            Text(
                              scheduled.isEmpty
                                  ? 'Nothing queued'
                                  : '${scheduled.length} post${scheduled.length == 1 ? '' : 's'} queued',
                              style: const TextStyle(
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
                if (state.loading && scheduled.isEmpty)
                  const GlassCard(child: ShimmerList(count: 4))
                else if (scheduled.isEmpty)
                  const GlassCard(
                    padding: EdgeInsets.symmetric(
                        horizontal: AevraSpace.md, vertical: AevraSpace.xl),
                    child: Column(
                      children: [
                        Icon(Icons.schedule_outlined,
                            size: 26, color: AevraColors.accent),
                        SizedBox(height: AevraSpace.sm),
                        Text(
                          'The queue is clear',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: AevraSpace.xxs),
                        Text(
                          'Approved content can be scheduled from the web app.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 11.5,
                              height: 1.5,
                              color: AevraColors.muted2),
                        ),
                      ],
                    ),
                  )
                else
                  for (final (i, p) in scheduled.indexed) ...[
                    Reveal(
                      index: i,
                      child: DepthCard(
                        elevation: GlassElevation.raised,
                        padding: const EdgeInsets.all(AevraSpace.md),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // A timetable column: mono figures, left-aligned and
                            // fixed width so times stack into a readable rail
                            // instead of drifting with the content beside them.
                            SizedBox(
                              width: 46,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _formatTime(p.scheduledFor),
                                    style: AevraType.mono(
                                        size: 12, color: AevraColors.text),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _formatDay(p.scheduledFor).toUpperCase(),
                                    style: AevraType.mono(size: 9),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 34,
                              margin:
                                  const EdgeInsets.only(right: AevraSpace.sm),
                              color: AevraColors.lineStrong,
                            ),
                            Expanded(
                              child: Text(
                                p.text?.isNotEmpty == true
                                    ? p.text!
                                    : 'Campaign post',
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    height: 1.45,
                                    fontWeight: FontWeight.w600),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: AevraSpace.xs),
                            Text(
                              p.status.replaceAll('_', ' '),
                              style: AevraType.mono(
                                  size: 9, color: AevraColors.muted),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AevraSpace.xs),
                  ],
              ],
            ),
          ),
        );
      },
    );
  }
}
