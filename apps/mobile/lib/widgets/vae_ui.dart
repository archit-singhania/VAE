import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../api/models.dart';
import '../theme/aevra_theme.dart';
import 'depth.dart';

class VaePageHeader extends StatelessWidget {
  const VaePageHeader(this.title, this.subtitle, {super.key});
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 8),
          Text(subtitle),
        ]),
      );
}

class VaeGlassCard extends StatelessWidget {
  const VaeGlassCard({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => GlassSurface(
        padding: const EdgeInsets.all(24),
        child: child,
      );
}

class VaeMetricCard extends StatelessWidget {
  const VaeMetricCard(this.label, this.value,
      {super.key, this.icon, this.hint});
  final String label, value;
  final IconData? icon;
  final String? hint;
  @override
  Widget build(BuildContext context) => VaeGlassCard(
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 10),
          ],
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 5),
          Text(value,
              style: AevraType.metric(28,
                  color: Theme.of(context).colorScheme.onSurface)),
          if (hint != null) ...[
            const SizedBox(height: 5),
            Text(hint!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ));
}

class VaeEmptyState extends StatelessWidget {
  const VaeEmptyState(this.title, this.body, {super.key, this.action});
  final String title, body;
  final Widget? action;
  @override
  Widget build(BuildContext context) => VaeGlassCard(
          child: Column(children: [
        Icon(LucideIcons.sparkles,
            color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 16),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(body, textAlign: TextAlign.center),
        if (action != null) ...[const SizedBox(height: 16), action!],
      ]));
}

class VaePrimaryButton extends StatelessWidget {
  const VaePrimaryButton(this.label,
      {super.key, this.onPressed, this.busy = false});
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  @override
  Widget build(BuildContext context) => FilledButton(
        onPressed: busy ? null : onPressed,
        child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(busy ? 'Working…' : label)),
      );
}

class VaeStatusPill extends StatelessWidget {
  const VaeStatusPill(this.status, {super.key});
  final String status;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color:
                Theme.of(context).colorScheme.primary.withValues(alpha: .12)),
        child: Text(status.replaceAll('_', ' '),
            style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 11,
                color: status == 'failed'
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.onSurface)),
      );
}

class VaeAssetTile extends StatelessWidget {
  const VaeAssetTile(this.asset, {super.key, this.onPublish});
  final MediaAsset asset;
  final VoidCallback? onPublish;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: VaeGlassCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (asset.downloadUrl != null && asset.mediaType == 'image')
              Semantics(
                  label: 'Preview ${asset.filename}',
                  button: true,
                  child: InkWell(
                      onTap: () =>
                          Navigator.of(context).push(PageRouteBuilder<void>(
                            opaque: false,
                            transitionDuration:
                                MediaQuery.disableAnimationsOf(context)
                                    ? Duration.zero
                                    : const Duration(milliseconds: 260),
                            pageBuilder:
                                (context, animation, secondaryAnimation) =>
                                    Scaffold(
                              backgroundColor: Colors.transparent,
                              body: BackdropFilter(
                                filter:
                                    ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                                child: ColoredBox(
                                    color: Colors.black87,
                                    child: SafeArea(
                                        child: Column(children: [
                                      Align(
                                          alignment: Alignment.topRight,
                                          child: IconButton(
                                              tooltip: 'Close preview',
                                              color: Colors.white,
                                              icon: const Icon(LucideIcons.x),
                                              onPressed: () =>
                                                  Navigator.pop(context))),
                                      Expanded(
                                          child: InteractiveViewer(
                                              child: Hero(
                                                  tag: 'asset-${asset.id}',
                                                  child: Image.network(
                                                      asset.downloadUrl!,
                                                      semanticLabel:
                                                          asset.filename,
                                                      fit: BoxFit.contain,
                                                      errorBuilder: (_, error,
                                                              stack) =>
                                                          const Icon(
                                                              LucideIcons
                                                                  .imageOff,
                                                              color: Colors
                                                                  .white))))),
                                    ]))),
                              ),
                            ),
                          )),
                      child: Hero(
                        tag: 'asset-${asset.id}',
                        child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(asset.downloadUrl!,
                                width: 72,
                                height: 72,
                                cacheWidth: 216,
                                fit: BoxFit.cover,
                                errorBuilder: (_, error, stack) =>
                                    const SizedBox(
                                        width: 72,
                                        height: 72,
                                        child: Icon(LucideIcons.imageOff)))),
                      )))
            else
              const Icon(LucideIcons.image),
            const SizedBox(width: 16),
            Expanded(
                child: Text(asset.filename,
                    maxLines: 2, overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 12),
          Wrap(
              spacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                VaeStatusPill(asset.status),
                if (onPublish != null && asset.status == 'ready')
                  TextButton(
                      onPressed: onPublish,
                      child: const Text('Use for publishing')),
              ]),
        ])),
      );
}

class VaeScaffold extends StatelessWidget {
  const VaeScaffold({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(AevraSpace.gutter),
        children: [
          Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: children)))
        ],
      );
}

class VaeBottomNav extends StatelessWidget {
  const VaeBottomNav(
      {super.key,
      required this.index,
      required this.onSelected,
      required this.onProfile,
      this.avatarUrl,
      this.admin = false});
  final int index;
  final ValueChanged<int> onSelected;
  final VoidCallback onProfile;
  final String? avatarUrl;
  final bool admin;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // Match the web app's phone rail: Home, Publish, Create, Analytics,
    // Profile. The desktop/admin rail still exposes the full page list.
    final destinations = admin
        ? const <(String, IconData, int)>[
            ('Home', LucideIcons.brainCircuit, 0),
            ('AI usage', LucideIcons.sparkles, 1),
            ('Publishing', LucideIcons.calendarDays, 2),
            ('Analytics', LucideIcons.brainCircuit, 3),
            ('Payment review', LucideIcons.shieldCheck, 4),
          ]
        : const <(String, IconData, int)>[
            ('Home', LucideIcons.brainCircuit, 0),
            ('Publish', LucideIcons.calendarDays, 2),
            ('Create', LucideIcons.sparkles, 1),
            ('Analytics', LucideIcons.brainCircuit, 3),
          ];

    Widget item(String label, IconData icon, VoidCallback onTap,
        {bool selected = false, bool primary = false, Widget? leading}) {
      final foreground = primary
          ? colors.onPrimary
          : selected
              ? colors.primary
              : colors.onSurfaceVariant;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          label: label,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AevraRadius.sm),
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AevraRadius.sm),
                color: primary
                    ? colors.primary
                    : selected
                        ? colors.primary.withValues(alpha: .10)
                        : Colors.transparent,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                leading ?? Icon(icon, size: 20, color: foreground),
                const SizedBox(height: 4),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: foreground)),
              ]),
            ),
          ),
        ),
      );
    }

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: .94),
            border:
                Border(top: BorderSide(color: Theme.of(context).dividerColor)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Row(children: [
                for (final (label, icon, page) in destinations)
                  item(label, icon, () => onSelected(page),
                      selected: index == page, primary: !admin && page == 1),
                item('Edit profile', LucideIcons.userRound, onProfile,
                    leading: avatarUrl == null
                        ? null
                        : ClipOval(
                            child: Image.network(
                              avatarUrl!,
                              width: 20,
                              height: 20,
                              fit: BoxFit.cover,
                              errorBuilder: (_, error, stack) => Icon(
                                  LucideIcons.userRound,
                                  size: 20,
                                  color: colors.onSurfaceVariant),
                            ),
                          )),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
