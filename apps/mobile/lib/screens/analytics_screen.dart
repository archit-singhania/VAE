import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../widgets/vae_ui.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key, required this.state});
  final AppState state;
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String channel = '';
  int days = 30;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) {
        final s = widget.state;
        final metrics = s.metrics
            .where((m) =>
                (channel.isEmpty || m.accountId == channel) &&
                m.collectedAt
                    .isAfter(DateTime.now().subtract(Duration(days: days))))
            .toList()
          ..sort((a, b) => a.collectedAt.compareTo(b.collectedAt));
        final max = metrics.fold<int>(
            1, (max, m) => m.engagements > max ? m.engagements : max);
        return VaeScaffold(children: [
          const VaePageHeader(
              'Analytics', 'See what resonates with your audience.'),
          Wrap(spacing: 16, children: [
            DropdownButton<String>(
                value: channel,
                items: [
                  const DropdownMenuItem(
                      value: '', child: Text('All channels')),
                  ...s.accounts.map((a) =>
                      DropdownMenuItem(value: a.id, child: Text(a.displayName)))
                ],
                onChanged: (v) => setState(() => channel = v!)),
            DropdownButton<int>(
                value: days,
                items: [7, 30, 90]
                    .map((n) =>
                        DropdownMenuItem(value: n, child: Text('Last $n days')))
                    .toList(),
                onChanged: (v) => setState(() => days = v!)),
          ]),
          const SizedBox(height: 16),
          VaeMetricCard('Impressions',
              '${metrics.fold<int>(0, (v, m) => v + m.impressions)}'),
          const SizedBox(height: 12),
          VaeMetricCard('Engagements',
              '${metrics.fold<int>(0, (v, m) => v + m.engagements)}'),
          const SizedBox(height: 24),
          if (metrics.isEmpty)
            const VaeEmptyState('Your story is just beginning',
                'Connect a channel and publish a post to see performance here.')
          else
            VaeGlassCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Channel performance',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 24),
                  ...metrics.take(20).map((m) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${m.postId} · ${m.engagements} engagements'),
                            const SizedBox(height: 8),
                            Semantics(
                                label: '${m.engagements} engagements',
                                child: LinearProgressIndicator(
                                    value: m.engagements / max, minHeight: 8)),
                            const SizedBox(height: 4),
                            Text(
                                '${m.impressions} impressions · ${m.collectedAt.toLocal()}',
                                style: Theme.of(context).textTheme.bodySmall)
                          ])))
                ])),
        ]);
      });
}
