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
  const VaeMetricCard(this.label, this.value, {super.key});
  final String label, value;
  @override
  Widget build(BuildContext context) => VaeGlassCard(
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(label)
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
        Icon(Icons.auto_awesome_outlined,
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
                                              icon: const Icon(Icons.close),
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
                                                              Icons
                                                                  .broken_image,
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
                                        child: Icon(
                                            Icons.broken_image_outlined)))),
                      )))
            else
              const Icon(Icons.image_outlined),
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
      this.admin = false});
  final int index;
  final ValueChanged<int> onSelected;
  final bool admin;
  @override
  Widget build(BuildContext context) => NavigationBar(
        selectedIndex: index,
        onDestinationSelected: onSelected,
        backgroundColor: Theme.of(context).colorScheme.surface,
        destinations: admin
            ? const [
                NavigationDestination(
                    icon: Icon(Icons.space_dashboard_outlined), label: 'Home'),
                NavigationDestination(
                    icon: Icon(Icons.auto_awesome_outlined), label: 'AI usage'),
                NavigationDestination(
                    icon: Icon(Icons.schedule_outlined), label: 'Publishing'),
                NavigationDestination(
                    icon: Icon(Icons.insights_outlined), label: 'Analytics'),
                NavigationDestination(
                    icon: Icon(Icons.verified_user_outlined),
                    label: 'Payments'),
              ]
            : const [
                NavigationDestination(
                    icon: Icon(Icons.space_dashboard_outlined), label: 'Home'),
                NavigationDestination(
                    icon: Icon(Icons.auto_awesome_outlined), label: 'Create'),
                NavigationDestination(
                    icon: Icon(Icons.schedule_outlined), label: 'Publish'),
                NavigationDestination(
                    icon: Icon(Icons.insights_outlined), label: 'Analytics'),
                NavigationDestination(
                    icon: Icon(Icons.psychology_outlined), label: 'ML'),
              ],
      );
}
