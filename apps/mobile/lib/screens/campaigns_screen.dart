import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api/models.dart';
import '../state/app_state.dart';
import '../theme/aevra_theme.dart';
import '../widgets/advanced_ui.dart';
import '../widgets/depth.dart';
import '../widgets/glass_card.dart';

class CampaignsScreen extends StatelessWidget {
  const CampaignsScreen({super.key, required this.state});

  final AppState state;

  /// One status vocabulary for the whole app: jade = done, amber = you owe
  /// it a decision, rose = it went wrong, grey = nothing has happened yet.
  Color _statusColor(BuildContext context, String status) => switch (status) {
        'approved' ||
        'ready' ||
        'published' =>
          Theme.of(context).colorScheme.secondary,
        'awaiting_approval' => Theme.of(context).brightness == Brightness.light
            ? AevraLightColors.amber
            : AevraColors.amber,
        'failed' || 'rejected' => Theme.of(context).colorScheme.error,
        _ => Theme.of(context).colorScheme.onSurfaceVariant,
      };

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        return AdaptiveGlassScroll(
          child: RefreshIndicator(
            onRefresh: state.load,
            color: Theme.of(context).colorScheme.primary,
            backgroundColor: Theme.of(context).colorScheme.surface,
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
                            Text('PIPELINE', style: AevraType.eyebrow()),
                            const SizedBox(height: AevraSpace.xs),
                            Text('Campaigns', style: AevraType.display(30)),
                            const SizedBox(height: AevraSpace.xxs),
                            Text(
                              '${state.campaigns.length} in this workspace · swipe a card to decide',
                              style: TextStyle(
                                  fontSize: 12,
                                  height: 1.45,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      // #6 — orb spins while a decision or refresh is in flight.
                      AiOrb(
                          size: 32,
                          state: state.loading
                              ? AiOrbState.thinking
                              : AiOrbState.idle),
                    ],
                  ),
                ),
                const SizedBox(height: AevraSpace.lg),
                if (state.loading && state.campaigns.isEmpty)
                  // #4 — skeleton shimmer in place of the bare spinner.
                  const GlassCard(child: ShimmerList(count: 4))
                else if (state.campaigns.isEmpty)
                  GlassCard(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AevraSpace.md, vertical: AevraSpace.xl),
                    child: Column(
                      children: [
                        Icon(LucideIcons.sparkles,
                            size: 26,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(height: AevraSpace.sm),
                        const Text(
                          'Nothing in the pipeline',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: AevraSpace.xxs),
                        Text(
                          'Create a campaign from the web app and it will appear here for approval.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 11.5,
                              height: 1.5,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant),
                        ),
                      ],
                    ),
                  )
                else
                  for (final (i, c) in state.campaigns.indexed) ...[
                    Reveal(
                      index: i,
                      child: Dismissible(
                        key: ValueKey(c.id),
                        direction: c.status == 'awaiting_approval'
                            ? DismissDirection.horizontal
                            : DismissDirection.none,
                        background: _swipeBackground(context,
                            alignLeft: true, approve: true),
                        secondaryBackground: _swipeBackground(context,
                            alignLeft: false, approve: false),
                        confirmDismiss: (direction) async {
                          HapticFeedback.mediumImpact();
                          final decision =
                              direction == DismissDirection.startToEnd
                                  ? 'approve'
                                  : 'reject';
                          await state.decide(c.id, decision);
                          // #3 + #16 — brass particle burst and ambient chime on
                          // a human decision, same trigger points as web.
                          if (context.mounted) AevraServices.celebrate(context);
                          return false; // let the card animate back; the list re-renders from state
                        },
                        // Tap is handled by the DepthCard below so the press
                        // also drives the tilt; an outer GestureDetector here
                        // would open the sheet twice.
                        child: Hero(
                          tag: 'campaign-${c.id}',
                          flightShuttleBuilder: (_, animation, __, ___, ____) =>
                              Material(
                                  color: Colors.transparent,
                                  child: FadeTransition(
                                      opacity: animation, child: _cardFor(c))),
                          child: DepthCard(
                            elevation: GlassElevation.floating,
                            padding: const EdgeInsets.all(16),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              _openDetail(context, c);
                            },
                            child: Row(
                              children: [
                                // A status spine down the left edge. It carries
                                // the same information as the chip but stays
                                // readable while scrolling, when the chip text
                                // is too small to parse.
                                Container(
                                  width: 3,
                                  height: 34,
                                  margin: const EdgeInsets.only(
                                      right: AevraSpace.sm),
                                  decoration: BoxDecoration(
                                    color: _statusColor(context, c.status),
                                    borderRadius:
                                        BorderRadius.circular(AevraRadius.pill),
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c.name,
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: -0.15,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        c.platforms.join('  ·  ').toUpperCase(),
                                        style: AevraType.mono(size: 9),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: AevraSpace.xs),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 9, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: _statusColor(context, c.status)
                                        .withValues(alpha: 0.10),
                                    borderRadius:
                                        BorderRadius.circular(AevraRadius.pill),
                                    border: Border.all(
                                      color: _statusColor(context, c.status)
                                          .withValues(alpha: 0.26),
                                    ),
                                  ),
                                  child: Text(
                                    c.status.replaceAll('_', ' '),
                                    style: AevraType.mono(
                                        size: 9,
                                        color: _statusColor(context, c.status)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _cardFor(Campaign c) => GlassCard(
        padding: const EdgeInsets.all(16),
        child: Text(c.name,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      );

  Widget _swipeBackground(BuildContext context,
      {required bool alignLeft, required bool approve}) {
    final color = approve
        ? Theme.of(context).colorScheme.secondary
        : Theme.of(context).colorScheme.error;
    return Container(
      alignment: alignLeft ? Alignment.centerLeft : Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        border: Border.all(
          color: color.withValues(alpha: 0.28),
        ),
        borderRadius: BorderRadius.circular(AevraRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            approve ? LucideIcons.check : LucideIcons.x,
            size: 18,
            color: color,
          ),
          const SizedBox(width: AevraSpace.xs),
          Text(
            approve ? 'APPROVE' : 'REJECT',
            style: AevraType.eyebrow(color: color),
          ),
        ],
      ),
    );
  }

  Future<void> _openDetail(BuildContext context, Campaign campaign) async {
    final token = state.token;
    final workspace = state.workspace;
    if (token == null || workspace == null) return;
    List<ContentVariant> variants = [];
    try {
      variants = await state.client.variants(token, workspace.id, campaign.id);
    } catch (_) {
      // Leave variants empty; the sheet still shows the campaign status.
    }
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _CampaignDetailSheet(
          state: state, campaign: campaign, variants: variants),
    );
  }
}

class _CampaignDetailSheet extends StatelessWidget {
  const _CampaignDetailSheet(
      {required this.state, required this.campaign, required this.variants});

  final AppState state;
  final Campaign campaign;
  final List<ContentVariant> variants;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        margin: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxHeight: 560),
        child: GlassSurface(
          elevation: GlassElevation.lifted,
          radius: AevraRadius.xl,
          padding: const EdgeInsets.all(AevraSpace.lg),
          adaptive: false,
          borderColor: Theme.of(context).dividerColor,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Grab handle. The sheet is draggable, and without an affordance
              // people tap the scrim to dismiss instead, losing the gesture.
              Center(
                child: Container(
                  width: 34,
                  height: 3,
                  margin: const EdgeInsets.only(bottom: AevraSpace.md),
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(AevraRadius.pill),
                  ),
                ),
              ),
              Hero(
                tag: 'campaign-${campaign.id}',
                child: Material(
                  color: Colors.transparent,
                  child: Text(campaign.name, style: AevraType.display(21)),
                ),
              ),
              const SizedBox(height: AevraSpace.xs),
              Text(
                campaign.status.replaceAll('_', ' ').toUpperCase(),
                style: AevraType.eyebrow(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: AevraSpace.md),
              Flexible(
                child: variants.isEmpty
                    ? Text('No generated variants yet.',
                        style: TextStyle(
                            fontSize: 12,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant))
                    : ListView.separated(
                        // #7 — variants stagger in as the sheet opens.
                        shrinkWrap: true,
                        itemCount: variants.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final v = variants[i];
                          return Reveal(
                            index: i,
                            // Deliberately a plain Container, not a GlassCard:
                            // this sits inside the lifted glass sheet, and a
                            // nested BackdropFilter would force a second
                            // saveLayer and re-blur the same pixels.
                            child: Container(
                              padding: const EdgeInsets.all(AevraSpace.sm),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .inputDecorationTheme
                                    .fillColor
                                    ?.withValues(alpha: 0.55),
                                borderRadius:
                                    BorderRadius.circular(AevraRadius.sm),
                                border: Border.all(
                                    color: Theme.of(context).dividerColor),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(v.platform.toUpperCase(),
                                          style: AevraType.eyebrow()),
                                      Text(
                                        '${v.qualityScore.round()}/100',
                                        style: AevraType.mono(
                                            size: 9.5,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .tertiary),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AevraSpace.xs),
                                  Text(
                                    v.caption,
                                    style: TextStyle(
                                        fontSize: 12.5,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                        height: 1.5),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              if (campaign.status == 'awaiting_approval') ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          AevraServices.maybeOf(context)?.sound.alert();
                          HapticFeedback.mediumImpact();
                          state.decide(campaign.id, 'reject');
                          Navigator.pop(context);
                        },
                        child: const Text('Request changes'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          AevraServices.celebrate(context);
                          state.decide(campaign.id, 'approve');
                          Navigator.pop(context);
                        },
                        child: const Text('Approve'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
