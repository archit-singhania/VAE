import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../widgets/vae_ui.dart';
import 'advanced_analytics_screen.dart';

class MlInsightsScreen extends StatefulWidget {
  const MlInsightsScreen({super.key, required this.state});
  final AppState state;
  @override
  State<MlInsightsScreen> createState() => _MlInsightsScreenState();
}

class _MlInsightsScreenState extends State<MlInsightsScreen> {
  final draft = TextEditingController();
  String platform = 'instagram';
  Map<String, dynamic>? report;
  String? error;
  String analyzedInput = '';
  bool busy = false;

  @override
  void dispose() {
    draft.dispose();
    super.dispose();
  }

  Future<void> analyze() async {
    final token = widget.state.token;
    final workspace = widget.state.workspace;
    if (token == null || workspace == null) return;
    final input = '${draft.text}|$platform';
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final next = await widget.state.client
          .mlInsights(token, workspace.id, draft.text, platform);
      if (mounted) {
        setState(() {
          report = next;
          analyzedInput = input;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final features = (report?['features'] as List?) ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('ML insights')),
      body: VaeScaffold(children: [
        const VaePageHeader('Learn from your work',
            'Ten workspace-local ML tools. Suggestions never publish or schedule automatically.'),
        OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => AdvancedAnalyticsScreen(
                    state: widget.state, initialDraft: draft.text))),
            icon: const Icon(Icons.insights),
            label: const Text('Open 3 advanced labs')),
        const SizedBox(height: 12),
        TextField(
            controller: draft,
            maxLength: 6000,
            minLines: 3,
            maxLines: 6,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
                labelText: 'Draft caption or creative brief')),
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
            onPressed: busy ? null : analyze,
            child: Text(busy ? 'Analyzing…' : 'Analyze workspace')),
        const SizedBox(height: 12),
        const Text(
            'Drafts are not saved. Leave the draft empty for topics, anomalies and forecasting. Predictions require enough history and a successful validation check.'),
        if (error != null)
          Text(error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (report != null && analyzedInput != '${draft.text}|$platform')
          const Text('Inputs changed. Analyze again to refresh these results.'),
        if (report == null)
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                  'Duplicate-copy detection · Brand-language match · Topic discovery · Media matching · Hashtag suggestions · Engagement prediction · Posting-time suggestions · Channel recommendations · Performance anomalies · Seven-day engagement forecast')),
        ...features.map((raw) {
          final feature = Map<String, dynamic>.from(raw as Map);
          final items = (feature['items'] as List?) ?? [];
          final diagnostics =
              Map<String, dynamic>.from(feature['diagnostics'] as Map? ?? {});
          return Padding(
              padding: const EdgeInsets.only(top: 16),
              child: VaeGlassCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${feature['title']}',
                          style: Theme.of(context).textTheme.titleLarge),
                      Text(feature['status'] == 'ready'
                          ? 'Analysis ready'
                          : feature['status'] == 'unreliable'
                              ? 'Prediction withheld'
                              : 'Needs data'),
                      const SizedBox(height: 8),
                      Text('${feature['explanation']}'),
                      Text(
                          '${feature['sample_count']} samples · Minimum ${feature['minimum_samples']}'),
                      ...items.map((rawItem) {
                        final item = Map<String, dynamic>.from(rawItem as Map);
                        return Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                                '${item['label']}\n${item['detail']}${item['score'] == null ? '' : ' · ${item['score']}'}'));
                      }),
                      if (items.isEmpty && feature['status'] == 'ready')
                        const Text(
                            'No matching suggestions or unusual patterns in this sample.'),
                      Material(
                          type: MaterialType.transparency,
                          child: ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              title: const Text('Method & validation'),
                              children: [
                                Text('${feature['method']}'),
                                ...diagnostics.entries.map((e) => Text(
                                    '${e.key.replaceAll('_', ' ')}: ${e.value}'))
                              ])),
                    ]),
              ));
        }),
        if (report != null)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text('Analysis audit · ${report!['model_version']}\n'
                  'Current workspace only. No external AI requests, persisted models, or automatic actions.\n'
                  'History capped: ${(report!['audit'] as Map)['history_capped']}\n'
                  '${((report!['audit'] as Map)['notes'] as List).join('\n')}')),
      ]),
    );
  }
}
