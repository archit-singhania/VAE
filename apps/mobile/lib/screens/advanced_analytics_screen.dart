import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../widgets/vae_ui.dart';

class AdvancedAnalyticsScreen extends StatefulWidget {
  const AdvancedAnalyticsScreen(
      {super.key, required this.state, this.initialDraft = ''});
  final AppState state;
  final String initialDraft;
  @override
  State<AdvancedAnalyticsScreen> createState() =>
      _AdvancedAnalyticsScreenState();
}

class _AdvancedAnalyticsScreenState extends State<AdvancedAnalyticsScreen> {
  late final a = TextEditingController(text: widget.initialDraft);
  final b = TextEditingController();
  String platform = 'instagram';
  String? selected, error;
  String analyzedInput = '';
  bool busy = false;
  Map<String, dynamic>? report;
  @override
  void dispose() {
    a.dispose();
    b.dispose();
    super.dispose();
  }

  String format(dynamic value) => value is num
      ? value.toStringAsFixed(value == value.roundToDouble() ? 0 : 3)
      : '—';
  Future<void> run() async {
    final token = widget.state.token;
    final workspace = widget.state.workspace;
    if (busy || token == null || workspace == null) return;
    final input = '${a.text}|${b.text}|$platform';
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final next = await widget.state.client
          .advancedInsights(token, workspace.id, a.text, b.text, platform);
      if (mounted) {
        setState(() {
          report = next;
          analyzedInput = input;
          selected = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget panel(String title, List<Widget> children) => Padding(
      padding: const EdgeInsets.only(top: 20),
      child: VaeGlassCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        ...children,
      ])));

  @override
  Widget build(BuildContext context) {
    final map = report?['content_map'] as Map?;
    final comparison = report?['comparison'] as Map?;
    final quality = report?['data_quality'] as Map?;
    final drift = quality?['drift'] as Map?;
    final points = ((map?['points'] as List?) ?? [])
        .map((p) => Map<String, dynamic>.from(p as Map))
        .toList();
    final selectedPoints = points.where((p) => p['id'] == selected);
    final selectedPoint = selectedPoints.isEmpty ? null : selectedPoints.first;
    return Scaffold(
        appBar: AppBar(title: const Text('Advanced analytics')),
        body: VaeScaffold(children: [
          const VaePageHeader('Three advanced labs',
              'Map your content, compare drafts, and inspect data health. Drafts are not saved and suggestions take no automatic actions.'),
          TextField(
              controller: a,
              maxLength: 6000,
              minLines: 2,
              maxLines: 4,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Draft A')),
          const SizedBox(height: 12),
          TextField(
              controller: b,
              maxLength: 6000,
              minLines: 2,
              maxLines: 4,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Draft B')),
          DropdownButton<String>(
              value: platform,
              items: [
                'instagram',
                'facebook',
                'linkedin',
                'threads',
                'x',
                'youtube'
              ].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
              onChanged: (value) => setState(() => platform = value!)),
          FilledButton(
              onPressed: busy ? null : run,
              child: Text(busy ? 'Analyzing…' : 'Run advanced analysis')),
          const Text(
              'Leave drafts blank to load the content map and data-quality checks only.'),
          if (error != null)
            Text(error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          if (report != null &&
              analyzedInput != '${a.text}|${b.text}|$platform')
            const Text('Inputs changed. Run again to refresh these results.'),
          if (map != null)
            panel('Content-performance map', [
              Text('${map['explanation']}'),
              if (map['status'] == 'ready') ...[
                const SizedBox(height: 12),
                Text(
                    '${points.length} captions · ${format((map['explained_variance'] as num) * 100)}% variance retained'),
                Semantics(
                  label:
                      'Two-dimensional content map. Inspect captions with the selector below.',
                  child: SizedBox(
                      height: 220,
                      width: double.infinity,
                      child: LayoutBuilder(
                          builder: (context, bounds) => GestureDetector(
                              onTapDown: (event) {
                                Map<String, dynamic>? nearest;
                                double distance = 400;
                                for (final point in points) {
                                  final offset = ContentMapPainter.position(
                                      point, Size(bounds.maxWidth, 220));
                                  final next = (offset - event.localPosition)
                                      .distanceSquared;
                                  if (next < distance) {
                                    distance = next;
                                    nearest = point;
                                  }
                                }
                                if (nearest != null) {
                                  setState(() =>
                                      selected = nearest!['id'] as String);
                                }
                              },
                              child: CustomPaint(
                                  painter: ContentMapPainter(points, selected),
                                  size: Size(bounds.maxWidth, 220))))),
                ),
                const Text(
                    'Filled: measured rate. Hollow: no measured rate. Position reflects wording, not content quality.'),
                DropdownButtonFormField<String>(
                    initialValue: selected,
                    key: ValueKey(selected),
                    isExpanded: true,
                    decoration: const InputDecoration(
                        labelText: 'Inspect a mapped caption'),
                    items: points
                        .map((p) => DropdownMenuItem(
                            value: p['id'] as String,
                            child: Text('${p['platform']}: ${p['caption']}',
                                maxLines: 1, overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (value) => setState(() => selected = value)),
                if (selectedPoint != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                          '${selectedPoint['caption']}\nTheme ${(selectedPoint['cluster'] as num) + 1} · ${selectedPoint['platform']}\nMeasured rate: ${format(selectedPoint['engagement_rate'])}')),
                ...((map['clusters'] as List?) ?? []).map((c) =>
                    Text('Theme ${(c['id'] as num) + 1}: ${c['label']}')),
              ],
            ]),
          if (comparison != null)
            panel('Draft comparison lab', [
              Text('${comparison['explanation']}'),
              if (comparison['status'] == 'ready') ...[
                Text(
                    'A: ${format(comparison['prediction_a'])} · B: ${format(comparison['prediction_b'])}'),
                Text(
                    'B minus A: ${format(comparison['delta'])} engagements per 100 impressions'),
                Text(
                    'Resampling range: ${format(comparison['delta_range'][0])} to ${format(comparison['delta_range'][1])}'),
                Text(
                    '${comparison['bootstrap_samples']} resamples · ${comparison['week_blocks']} weeks'),
                if (comparison['delta_range'][0] <= 0 &&
                    comparison['delta_range'][1] >= 0)
                  const Text(
                      'Range includes zero: no stable model preference.'),
              ] else
                const Text(
                    'Comparison withheld until inputs and validation requirements are met.'),
              ...Map<String, dynamic>.from(
                      comparison['diagnostics'] as Map? ?? {})
                  .entries
                  .map(
                      (e) => Text('${e.key.replaceAll('_', ' ')}: ${e.value}')),
            ]),
          if (quality != null && drift != null)
            panel('Data health & distribution shifts', [
              Text('${quality['explanation']}'),
              Text(
                  'Seven-day label coverage: ${format(quality['coverage_percent'])}${quality['coverage_percent'] == null ? '' : '%'}'),
              Text(
                  '${format(quality['matched_posts'])} / ${format(quality['mature_posts'])} mature posts'),
              Text(
                  'Latest collection age: ${format(quality['freshness_hours'])} hours'),
              Text(
                  '${quality['observed_days']} observed days / 35 · ${quality['missing_days']} missing'),
              const SizedBox(height: 12),
              GridView.count(
                  crossAxisCount: 7,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 3,
                  mainAxisSpacing: 3,
                  childAspectRatio: 0.45,
                  children: (quality['timeline'] as List)
                      .map((day) => Semantics(
                          label:
                              '${day['date']}: ${day['observed_posts']} observed posts',
                          child: Container(
                              decoration: BoxDecoration(
                                  border: Border.all(
                                      color: Theme.of(context).dividerColor),
                                  borderRadius: BorderRadius.circular(4),
                                  color: day['observed_posts'] > 0
                                      ? Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.15)
                                      : null),
                              child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('${day['date']}'.substring(5),
                                        style: const TextStyle(fontSize: 9)),
                                    Text('${day['observed_posts']}',
                                        style: const TextStyle(fontSize: 12)),
                                  ]))))
                      .toList()),
              const Text(
                  'UTC calendar · Zero means no observations, not zero engagement.'),
              const SizedBox(height: 16),
              Text('Distribution check · ${report!['platform']}',
                  style: Theme.of(context).textTheme.titleMedium),
              Text('${drift['explanation']}'),
              Text(
                  'Previous: ${drift['previous_samples']} posts · Recent: ${drift['recent_samples']} posts'),
              Text(
                  '${drift['previous_start'].toString().substring(0, 10)} → ${drift['recent_start'].toString().substring(0, 10)} → ${drift['window_end'].toString().substring(0, 10)} UTC'),
              if (drift['status'] != 'needs_data') ...[
                Text(drift['status'] == 'difference_detected'
                    ? 'Distribution difference detected — investigate'
                    : 'No clear difference detected'),
                Text(
                    'Median: ${format(drift['previous_median'])} → ${format(drift['recent_median'])}'),
                Text(
                    'KS distance: ${format(drift['ks_distance'])} · Permutation p: ${format(drift['permutation_p'])}'),
              ],
              if (quality['history_capped'] == true)
                const Text(
                    'History is capped; coverage describes the sampled dataset.'),
            ]),
          if (report != null)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                    '${report!['version']} · ${report!['generated_at']}\nCurrent workspace only · No external AI calls or automatic actions.')),
        ]));
  }
}

class ContentMapPainter extends CustomPainter {
  ContentMapPainter(this.points, this.selected);
  final List<Map<String, dynamic>> points;
  final String? selected;
  static const colors = [
    Color(0xff9a5a2e),
    Color(0xff327d70),
    Color(0xff567dad),
    Color(0xff8a61a8),
    Color(0xffad654d)
  ];
  static Offset position(Map<String, dynamic> p, Size size) => Offset(
      12 + (p['x'] as num) * (size.width - 24),
      12 + (1 - (p['y'] as num)) * (size.height - 24));
  @override
  void paint(Canvas canvas, Size size) {
    for (final point in points) {
      final paint = Paint()
        ..color = colors[(point['cluster'] as int) % colors.length]
        ..style = point['engagement_rate'] == null
            ? PaintingStyle.stroke
            : PaintingStyle.fill
        ..strokeWidth = point['id'] == selected ? 3 : 1.5;
      canvas.drawCircle(
          position(point, size), point['id'] == selected ? 8 : 4, paint);
    }
  }

  @override
  bool shouldRepaint(covariant ContentMapPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.selected != selected;
}
