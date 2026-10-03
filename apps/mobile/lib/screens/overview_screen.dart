import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/models.dart';
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
          const SizedBox(height: 28),
          _sectionHeading(context, 'At a glance', 'Your workspace, in focus.'),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, constraints) {
            final columns = _gridColumns(context, constraints.maxWidth);
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
          const SizedBox(height: 28),
          _schedulePanel(context),
          const SizedBox(height: 28),
          _mediaPanel(context),
          const SizedBox(height: 28),
          _quickActions(context),
          const SizedBox(height: 12),
        ]),
      );

  int _gridColumns(BuildContext context, double width) {
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    if (width > 800 && scale < 1.4) return 4;
    if (width < 220 || (width < 300 && scale > 1.25) || scale > 1.8) {
      return 1;
    }
    return 2;
  }

  Widget _hero(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final name = state.user?.displayName.trim().split(RegExp(r'\s+')).first;
    return VaeGlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(width: 24, height: 2, color: colors.primary),
            Text('YOUR CREATIVE SPACE',
                style: AevraType.eyebrow(color: colors.primary)),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Good to see you${name == null || name.isEmpty ? '' : ', $name'}.',
          style: theme.textTheme.displaySmall?.copyWith(height: 1.15),
        ),
        const SizedBox(height: 12),
        Text('Bring your next idea to life. Your studio is ready when you are.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: colors.onSurfaceVariant, height: 1.65)),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => onNavigate?.call(1),
          icon: const Icon(LucideIcons.plus, size: 17),
          label: const Text('Create media'),
        ),
      ]),
    );
  }

  Widget _sectionHeading(BuildContext context, String title, String subtitle,
      {String? action, VoidCallback? onAction}) {
    final theme = Theme.of(context);
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 5),
        Text(subtitle,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
    if (action == null) return heading;
    final button = TextButton(
      onPressed: onAction,
      child: Text(action),
    );
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 340 ||
          MediaQuery.textScalerOf(context).scale(14) > 18) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [heading, const SizedBox(height: 4), button],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: heading),
          const SizedBox(width: 8),
          button,
        ],
      );
    });
  }

  Widget _schedulePanel(BuildContext context) {
    final posts = state.scheduled.take(4).toList();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _sectionHeading(context, 'Publishing', 'Every idea has its moment.',
          action: 'View all', onAction: () => onNavigate?.call(2)),
      const SizedBox(height: 16),
      VaeGlassCard(
        child: posts.isEmpty
            ? _empty(
                context,
                LucideIcons.calendarDays,
                'Your next chapter awaits',
                'Schedule your first post and find it here.',
                action: 'Plan a post',
                onAction: () => onNavigate?.call(2))
            : Column(
                children: [
                  for (var index = 0; index < posts.length; index++) ...[
                    if (index > 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: Divider(height: 1, color: theme.dividerColor),
                      ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _iconWell(context, LucideIcons.calendarDays),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  _scheduleTime(
                                      context, posts[index].scheduledFor),
                                  style: theme.textTheme.titleSmall),
                              const SizedBox(height: 6),
                              Text(
                                posts[index].text?.trim().isNotEmpty == true
                                    ? posts[index].text!
                                    : 'Media post',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                    height: 1.5),
                              ),
                              const SizedBox(height: 10),
                              VaeStatusPill(posts[index].status),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
      ),
    ]);
  }

  String _scheduleTime(BuildContext context, String value) {
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return value;
    final localizations = MaterialLocalizations.of(context);
    final day = localizations.formatMediumDate(date);
    final time = localizations.formatTimeOfDay(TimeOfDay.fromDateTime(date),
        alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context));
    return '$day · $time';
  }

  Widget _mediaPanel(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeading(
              context, 'Recent media', 'A collection of your ideas.',
              action: 'View library', onAction: () => onNavigate?.call(1)),
          const SizedBox(height: 16),
          if (state.assets.isEmpty)
            VaeGlassCard(
              child: _empty(
                  context,
                  LucideIcons.image,
                  'A space for your best work',
                  'Create your first image or caption to start your collection.'),
            )
          else
            LayoutBuilder(builder: (context, constraints) {
              final columns = _gridColumns(context, constraints.maxWidth);
              final width =
                  (constraints.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final asset in state.assets.take(4))
                    SizedBox(width: width, child: _mediaCard(context, asset)),
                ],
              );
            }),
        ],
      );

  Widget _mediaCard(BuildContext context, MediaAsset asset) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final radius = BorderRadius.circular(AevraRadius.md);
    final imageAvailable = asset.mediaType == 'image' &&
        asset.downloadUrl != null &&
        asset.downloadUrl!.isNotEmpty;
    Widget placeholder(IconData icon) => ColoredBox(
          color: colors.primary.withValues(alpha: .06),
          child: Center(
              child: Icon(icon, size: 28, color: colors.onSurfaceVariant)),
        );
    return Material(
      color: colors.surface,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          state.selectForPublishing(asset.id);
          onNavigate?.call(2);
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: theme.dividerColor),
            borderRadius: radius,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 1.18,
                child: imageAvailable
                    ? Image.network(
                        asset.downloadUrl!,
                        fit: BoxFit.cover,
                        cacheWidth: 640,
                        semanticLabel: asset.filename,
                        errorBuilder: (_, error, stack) =>
                            placeholder(LucideIcons.imageOff),
                      )
                    : placeholder(asset.mediaType == 'video'
                        ? LucideIcons.video
                        : asset.mediaType == 'image'
                            ? LucideIcons.image
                            : LucideIcons.fileText),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(asset.filename,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Text(
                        '${asset.mediaType} · ${asset.status.replaceAll('_', ' ')}',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant, fontSize: 11)),
                    const SizedBox(height: 12),
                    Text('Use for publishing',
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickActions(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeading(context, 'Keep creating', 'Make your next move.'),
          const SizedBox(height: 16),
          VaeGlassCard(
            child: Column(children: [
              _action(
                  context,
                  LucideIcons.sparkles,
                  'Open the studio',
                  'Turn a prompt into something worth sharing.',
                  () => onNavigate?.call(1)),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(height: 1),
              ),
              _action(
                  context,
                  LucideIcons.send,
                  !state.accounts
                          .any((account) => account.status == 'connected')
                      ? 'Connect a channel'
                      : 'Plan your publishing',
                  'Bring your content to the right audience.',
                  () => onNavigate?.call(2)),
              if (onCampaigns != null) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(height: 1),
                ),
                _action(context, LucideIcons.megaphone, 'Campaigns',
                    'Give your next campaign a clear direction.', onCampaigns!),
              ],
            ]),
          ),
        ],
      );

  Widget _iconWell(BuildContext context, IconData icon) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: .10)),
        ),
        child:
            Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
      );

  Widget _action(BuildContext context, IconData icon, String title,
      String subtitle, VoidCallback onTap) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AevraRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _iconWell(context, icon),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 5),
                    Text(subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.5)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Icon(LucideIcons.chevronRight,
                    size: 15, color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _empty(BuildContext context, IconData icon, String title, String body,
      {String? action, VoidCallback? onAction}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(children: [
        _iconWell(context, icon),
        const SizedBox(height: 18),
        Text(title,
            textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant, height: 1.65)),
        if (action != null) ...[
          const SizedBox(height: 12),
          TextButton(onPressed: onAction, child: Text(action)),
        ],
      ]),
    );
  }
}
