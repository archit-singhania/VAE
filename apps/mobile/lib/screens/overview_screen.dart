import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../widgets/vae_ui.dart';

class OverviewScreen extends StatelessWidget {
  const OverviewScreen({super.key, required this.state, this.onNavigate});
  final AppState state;
  final ValueChanged<int>? onNavigate;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: state,
      builder: (context, _) => VaeScaffold(children: [
            VaePageHeader(
                'Good to see you, ${state.user?.displayName.split(' ').first ?? 'there'}.',
                'Create media, connect channels, and publish from one place.'),
            Wrap(spacing: 12, children: [
              VaePrimaryButton('Create media',
                  onPressed: () => onNavigate?.call(1)),
              OutlinedButton(
                  onPressed: () => onNavigate?.call(2),
                  child: const Text('Publish'))
            ]),
            const SizedBox(height: 24),
            LayoutBuilder(
                builder: (context, constraints) => Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      ['Media assets', '${state.assets.length}'],
                      [
                        'Connected channels',
                        '${state.accounts.where((a) => a.status == 'connected').length}'
                      ],
                      [
                        'Scheduled posts',
                        '${state.scheduled.where((p) => p.status == 'scheduled').length}'
                      ],
                      [
                        'Engagement',
                        '${state.metrics.fold<int>(0, (sum, m) => sum + m.engagements)}'
                      ],
                    ]
                        .map((m) => SizedBox(
                            width: (constraints.maxWidth -
                                    (constraints.maxWidth > 700 ? 36 : 12)) /
                                (constraints.maxWidth > 700 ? 4 : 2),
                            child: VaeMetricCard(m[0], m[1])))
                        .toList())),
            const SizedBox(height: 32),
            Text('Recent media',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            if (state.assets.isEmpty)
              const VaeEmptyState('Your library is ready',
                  'Create a visual or upload your own media to get started.'),
            ...state.assets.take(4).map((a) => VaeAssetTile(a, onPublish: () {
                  state.selectForPublishing(a.id);
                  onNavigate?.call(2);
                })),
            const SizedBox(height: 24),
            Text('Coming up next',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            if (state.scheduled.isEmpty)
              const VaeEmptyState('Make room for your next idea',
                  'Choose an asset and schedule your first post.'),
            ...state.scheduled.take(4).map((p) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule),
                title: Text(p.text ?? 'Media post'),
                subtitle: Text(p.scheduledFor),
                trailing: VaeStatusPill(p.status))),
          ]));
}
