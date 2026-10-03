import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../api/models.dart';
import '../theme/aevra_theme.dart';
import 'depth.dart';
import 'advanced_ui.dart';

class VaePageHeader extends StatelessWidget {
  const VaePageHeader(this.title, this.subtitle, {super.key});
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 28,
            height: 3,
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(3)),
          ),
          Text(title, style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Text(subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
        ]),
      );
}

class VaeGlassCard extends StatelessWidget {
  const VaeGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.radius = 24,
    this.elevation = GlassElevation.raised,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final GlassElevation elevation;
  @override
  Widget build(BuildContext context) => GlassSurface(
        padding: padding,
        radius: radius,
        elevation: elevation,
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
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return VaeGlassCard(
        padding: const EdgeInsets.all(18),
        radius: 22,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null)
              Container(
                width: 34,
                height: 34,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(11),
                  border:
                      Border.all(color: colors.primary.withValues(alpha: .12)),
                ),
                child: Icon(icon, size: 16, color: colors.primary),
              ),
            Text(label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Text(value, style: AevraType.metric(34, color: colors.onSurface)),
            if (hint != null) ...[
              const SizedBox(height: 18),
              Divider(color: Theme.of(context).dividerColor),
              const SizedBox(height: 10),
              Text(hint!,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontSize: 10.5)),
            ],
          ],
        ));
  }
}

class VaeEmptyState extends StatelessWidget {
  const VaeEmptyState(this.title, this.body, {super.key, this.action});
  final String title, body;
  final Widget? action;
  @override
  Widget build(BuildContext context) => VaeGlassCard(
          child: Column(children: [
        Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: .07),
                border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: .12))),
            child: Icon(LucideIcons.sparkles,
                size: 23, color: Theme.of(context).colorScheme.primary)),
        const SizedBox(height: 20),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Text(body,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant))),
        if (action != null) ...[const SizedBox(height: 24), action!],
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
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = switch (status.toLowerCase()) {
      'failed' || 'rejected' || 'error' || 'disconnected' => colors.error,
      'ready' ||
      'connected' ||
      'published' ||
      'approved' ||
      'completed' =>
        colors.secondary,
      'pending' ||
      'under_review' ||
      'processing' ||
      'queued' =>
        Theme.of(context).brightness == Brightness.dark
            ? AevraColors.amber
            : AevraLightColors.amber,
      _ => colors.primary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: color.withValues(alpha: .18)),
          color: color.withValues(alpha: .08)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Flexible(
            child: Text(status.replaceAll('_', ' '),
                style: TextStyle(
                    fontFamily: 'Manrope',
                    fontWeight: FontWeight.w600,
                    fontSize: 10.5,
                    color: color))),
      ]),
    );
  }
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
                            transitionDuration: reduceMotion(context)
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
        padding: EdgeInsets.fromLTRB(
          MediaQuery.sizeOf(context).width >= 900 ? 28 : AevraSpace.gutter,
          16,
          MediaQuery.sizeOf(context).width >= 900 ? 28 : AevraSpace.gutter,
          24,
        ),
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
  const VaeBottomNav({
    super.key,
    required this.index,
    required this.onSelected,
    required this.onProfile,
    this.avatarUrl,
    this.admin = false,
  });
  final int index;
  final ValueChanged<int> onSelected;
  final VoidCallback onProfile;
  final String? avatarUrl;
  final bool admin;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final destinations = admin
        ? const <(String, IconData, int)>[
            ('Home', LucideIcons.layoutDashboard, 0),
            ('AI usage', LucideIcons.sparkles, 1),
            ('Publishing', LucideIcons.calendarDays, 2),
            ('Analytics', LucideIcons.chartNoAxesCombined, 3),
            ('Review', LucideIcons.shieldCheck, 4),
          ]
        : const <(String, IconData, int)>[
            ('Home', LucideIcons.layoutDashboard, 0),
            ('Publish', LucideIcons.calendarDays, 2),
            ('Create', LucideIcons.sparkles, 1),
            ('Analytics', LucideIcons.chartNoAxesCombined, 3),
            ('Profile', LucideIcons.userRound, -1),
          ];
    final slot =
        destinations.indexWhere((destination) => destination.$3 == index);
    final tall = MediaQuery.textScalerOf(context).scale(10) > 15;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: GlassChrome(
            radius: 34,
            padding: const EdgeInsets.all(6),
            child: LayoutBuilder(builder: (context, constraints) {
              final itemWidth = constraints.maxWidth / destinations.length;
              return SizedBox(
                height: tall ? 72 : 64,
                child: Stack(children: [
                  if (slot >= 0)
                    AnimatedPositioned(
                      duration: reduceMotion(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 360),
                      curve: Curves.easeOutCubic,
                      left: slot * itemWidth,
                      top: 0,
                      bottom: 0,
                      width: itemWidth,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: .13),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                              color: colors.primary.withValues(alpha: .15)),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              colors.primary.withValues(alpha: .18),
                              colors.primary.withValues(alpha: .08),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Row(children: [
                    for (final (label, icon, page) in destinations)
                      Expanded(
                        child: _GlassNavControl(
                          label: label,
                          icon: icon,
                          selected: index == page,
                          primary: !admin && page == 1,
                          onTap: page < 0 ? onProfile : () => onSelected(page),
                          avatarUrl: page < 0 ? avatarUrl : null,
                        ),
                      ),
                  ]),
                ]),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _GlassNavControl extends StatefulWidget {
  const _GlassNavControl({
    required this.label,
    required this.icon,
    required this.selected,
    required this.primary,
    required this.onTap,
    this.avatarUrl,
  });
  final String label;
  final IconData icon;
  final bool selected, primary;
  final VoidCallback onTap;
  final String? avatarUrl;

  @override
  State<_GlassNavControl> createState() => _GlassNavControlState();
}

class _GlassNavControlState extends State<_GlassNavControl> {
  bool pressed = false;
  void _press(bool value) {
    if (pressed != value) setState(() => pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground =
        widget.selected ? colors.primary : colors.onSurfaceVariant;
    final label = widget.label == 'Review' ? 'Payment review' : widget.label;
    return Semantics(
      button: true,
      selected: widget.selected,
      label: label,
      onTap: widget.onTap,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: widget.onTap,
          onTapDown: (_) => _press(true),
          onTapUp: (_) => _press(false),
          onTapCancel: () => _press(false),
          borderRadius: BorderRadius.circular(28),
          child: AnimatedScale(
            scale: pressed && !reduceMotion(context) ? .94 : 1,
            duration: reduceMotion(context)
                ? Duration.zero
                : const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 32,
                    height: 28,
                    decoration: widget.primary
                        ? BoxDecoration(
                            color: colors.primary,
                            borderRadius: BorderRadius.circular(14),
                          )
                        : null,
                    child: Center(
                      child: widget.avatarUrl == null
                          ? Icon(widget.icon,
                              size: 19,
                              color: widget.primary
                                  ? colors.onPrimary
                                  : foreground)
                          : ClipOval(
                              child: Image.network(widget.avatarUrl!,
                                  width: 22,
                                  height: 22,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, error, stack) => Icon(
                                      widget.icon,
                                      size: 19,
                                      color: foreground)),
                            ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 10,
                        height: 1.1,
                        fontWeight:
                            widget.selected ? FontWeight.w700 : FontWeight.w600,
                        color: foreground,
                      )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
