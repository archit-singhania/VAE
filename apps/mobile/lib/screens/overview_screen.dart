import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../state/app_state.dart';
import '../theme/aevra_theme.dart';
import '../widgets/vae_ui.dart';

class OverviewScreen extends StatelessWidget {
  const OverviewScreen(
      {super.key, required this.state, this.onNavigate, this.onCampaigns});

  final AppState state;
  final ValueChanged<int>? onNavigate;
  final VoidCallback? onCampaigns;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: state,
        builder: (context, _) => VaeScaffold(children: [
          _hero(context),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, constraints) {
            final columns = constraints.maxWidth > 700 ? 4 : 2;
            final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
            final metrics = <(IconData, String, String, String)>[
              (
                LucideIcons.image,
                'Media assets',
                '${state.assets.length}',
                'in your library'
              ),
              (
                LucideIcons.send,
                'Connected channels',
                '${state.accounts.where((a) => a.status == 'connected').length}',
                'ready to publish'
              ),
              (
                LucideIcons.calendarDays,
                'Scheduled',
                '${state.scheduled.where((p) => p.status == 'scheduled').length}',
                'upcoming posts'
              ),
              (
                LucideIcons.sparkles,
                'Engagement',
                '${state.metrics.fold<int>(0, (sum, m) => sum + m.engagements)}',
                'recorded interactions'
              ),
            ];
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final (icon, label, value, hint) in metrics)
                  SizedBox(
                    width: width,
                    child: VaeMetricCard(label, value, icon: icon, hint: hint),
                  ),
              ],
            );
          }),
          const SizedBox(height: 12),
          _schedulePanel(context),
          const SizedBox(height: 12),
          _mediaPanel(context),
          const SizedBox(height: 12),
          _quickActions(context),
        ]),
      );

  Widget _hero(BuildContext context) => VaeGlassCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('YOUR CONTENT HOME', style: AevraType.eyebrow()),
          const SizedBox(height: 8),
          Text(
            'Good to see you, ${state.user?.displayName.split(' ').first ?? 'there'}.',
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 8),
          Text('Create media, connect channels, and publish from one place.',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 20),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(
              onPressed: () => onNavigate?.call(1),
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('Create media'),
            ),
            OutlinedButton.icon(
              onPressed: () => onNavigate?.call(2),
              icon: const Icon(LucideIcons.calendarDays, size: 16),
              label: const Text('Publish'),
            ),
            OutlinedButton.icon(
              onPressed: onCampaigns,
              icon: const Icon(LucideIcons.megaphone, size: 16),
              label: const Text('Campaigns'),
            ),
          ]),
        ]),
      );

  Widget _schedulePanel(BuildContext context) => VaeGlassCard(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: Text('Coming up next',
                  style: Theme.of(context).textTheme.headlineSmall),
            ),
            TextButton(
                onPressed: () => onNavigate?.call(2),
                child: const Text('Publish')),
          ]),
          const SizedBox(height: 12),
          if (state.scheduled.isEmpty)
            _empty(
                context,
                LucideIcons.calendarDays,
                'Make room for your next idea',
                'Choose an asset and schedule your first post.'),
          for (final post in state.scheduled.take(4))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.calendarDays, size: 18),
              title: Text(post.scheduledFor),
              subtitle: Text(post.text ?? 'Media post', maxLines: 2),
              trailing: VaeStatusPill(post.status),
            ),
        ]),
      );

  Widget _mediaPanel(BuildContext context) => VaeGlassCard(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('YOUR LIBRARY', style: AevraType.eyebrow()),
          Row(children: [
            Expanded(
              child: Text('Recent media',
                  style: Theme.of(context).textTheme.headlineSmall),
            ),
            TextButton.icon(
              onPressed: () => onNavigate?.call(1),
              icon: const Icon(LucideIcons.plus, size: 15),
              label: const Text('Create media'),
            ),
          ]),
          const SizedBox(height: 12),
          if (state.assets.isEmpty)
            _empty(context, LucideIcons.image, 'Your media library is ready',
                'Create an image or caption to see it here.'),
          for (final asset in state.assets.take(4))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.image, size: 18),
              title: Text(asset.filename,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${asset.mediaType} · ${asset.status}'),
              trailing: const Icon(LucideIcons.arrowRight, size: 16),
              onTap: () {
                state.selectForPublishing(asset.id);
                onNavigate?.call(2);
              },
            ),
        ]),
      );

  Widget _quickActions(BuildContext context) => VaeGlassCard(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('NEXT BEST ACTIONS', style: AevraType.eyebrow()),
          const SizedBox(height: 5),
          Text('Shape the workspace',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          _action(
              context,
              LucideIcons.sparkles,
              'Start creating',
              'Generate an image or caption from a prompt.',
              () => onNavigate?.call(1)),
          const SizedBox(height: 8),
          _action(
              context,
              LucideIcons.send,
              state.accounts.isEmpty
                  ? 'Connect a channel'
                  : 'Review publishing',
              'Choose an asset, write a caption, and pick the right moment.',
              () => onNavigate?.call(2)),
        ]),
      );

  Widget _action(BuildContext context, IconData icon, String title,
          String subtitle, VoidCallback onTap) =>
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AevraRadius.sm),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(AevraRadius.sm),
            ),
            child: ListTile(
              leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
              title: Text(title),
              subtitle: Text(subtitle),
              trailing: const Icon(LucideIcons.arrowRight, size: 16),
            ),
          ),
        ),
      );

  Widget _empty(
          BuildContext context, IconData icon, String title, String body) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(children: [
          Icon(icon, size: 23, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 8),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 5),
          Text(body,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ]),
      );
}
