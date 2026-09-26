import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../state/app_state.dart';
import '../widgets/vae_ui.dart';

class AdvancedScreen extends StatefulWidget {
  const AdvancedScreen(
      {super.key,
      required this.state,
      this.admin = false,
      this.adminSection = 'overview'});
  final AppState state;
  final bool admin;
  final String adminSection;
  @override
  State<AdvancedScreen> createState() => _AdvancedScreenState();
}

class _AdvancedScreenState extends State<AdvancedScreen> {
  Map<String, dynamic>? overview;
  List<Map<String, dynamic>> payments = [];
  String? error, notice;
  final brandName = TextEditingController();
  final brandDescription = TextEditingController();
  final sourceTitle = TextEditingController();
  final sourceContent = TextEditingController();
  final query = TextEditingController();
  final brandForm = GlobalKey<FormState>();
  final sourceForm = GlobalKey<FormState>();
  List<Map<String, dynamic>> citations = [];
  bool searched = false;

  @override
  void dispose() {
    for (final controller in [
      brandName,
      brandDescription,
      sourceTitle,
      sourceContent,
      query
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> runSourceAction(
      Future<void> Function(String, String) action) async {
    final token = widget.state.token;
    final workspace = widget.state.workspace;
    if (token == null || workspace == null) return;
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      await action(token, workspace.id);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> createBrand() async {
    if (!brandForm.currentState!.validate()) return;
    final name = brandName.text.trim(),
        description = brandDescription.text.trim();
    await runSourceAction((token, workspaceId) async {
      final brand = await widget.state.client
          .createBrand(token, workspaceId, name, description);
      widget.state.addBrand(brand);
      if (mounted) {
        brandName.clear();
        brandDescription.clear();
        notice = 'Brand saved.';
      }
    });
  }

  Future<void> ingest() async {
    if (!sourceForm.currentState!.validate()) return;
    final title = sourceTitle.text.trim(), content = sourceContent.text.trim();
    await runSourceAction((token, workspaceId) async {
      final document = await widget.state.client.ingestSource(
          token, workspaceId, title, content,
          brandId: widget.state.brands.firstOrNull?.id);
      widget.state.addDocument(document);
      if (mounted) {
        sourceTitle.clear();
        sourceContent.clear();
        notice = 'Source added to brand knowledge.';
      }
    });
  }

  Future<void> search() async {
    final text = query.text.trim();
    if (text.isEmpty) {
      setState(() => error = 'Enter a question to search your sources.');
      return;
    }
    await runSourceAction((token, workspaceId) async {
      final results = await widget.state.client.searchKnowledge(
          token, workspaceId, text,
          brandId: widget.state.brands.firstOrNull?.id);
      if (mounted) {
        setState(() {
          citations = results;
          searched = true;
        });
      }
    });
  }

  String? requiredText(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required.' : null;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    if (widget.admin) load();
  }

  Future<void> load() async {
    if (widget.state.user?.isAdmin != true || widget.state.token == null) {
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final results = await Future.wait([
        widget.state.client.adminOverview(widget.state.token!),
        widget.state.client.adminPayments(widget.state.token!)
      ]);
      if (mounted) {
        setState(() {
          overview = results[0] as Map<String, dynamic>;
          payments = results[1] as List<Map<String, dynamic>>;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> review(Map<String, dynamic> payment, String decision) async {
    final note = TextEditingController();
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text('$decision payment?'),
                content: TextField(
                    controller: note,
                    decoration:
                        const InputDecoration(labelText: 'Review note')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Confirm'))
                ]));
    final message = note.text.trim();
    note.dispose();
    if (confirmed != true || !mounted) return;
    if (decision == 'reject' && message.isEmpty) {
      setState(() => error = 'Add a reason for rejecting this payment.');
      return;
    }
    setState(() => busy = true);
    try {
      await widget.state.client.reviewPayment(
          widget.state.token!, payment['id'] as String, decision, message);
      await load();
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = e.toString();
        });
      }
    }
  }

  List<MapEntry<String, Object>> get adminMetrics {
    final totals = Map<String, dynamic>.from(overview?['totals'] as Map? ?? {});
    return switch (widget.adminSection) {
      'media' => [
          MapEntry('Generation runs', totals['generation_runs'] ?? 0),
          MapEntry('Generated assets', totals['generated_assets'] ?? 0),
          MapEntry('Input tokens recorded', totals['prompt_tokens'] ?? 0),
          MapEntry('Output tokens recorded', totals['completion_tokens'] ?? 0),
        ],
      'publishing' => [
          MapEntry('Channels', totals['channels'] ?? 0),
          MapEntry('Upcoming schedules', totals['scheduled'] ?? 0),
          MapEntry('Published posts', totals['published'] ?? 0),
          MapEntry('Failed publish jobs', totals['failed'] ?? 0),
        ],
      'analytics' => [
          MapEntry('Measured posts', totals['measured_posts'] ?? 0),
          MapEntry('Impressions', totals['impressions'] ?? 0),
          MapEntry('Engagements', totals['engagements'] ?? 0),
          MapEntry('Clicks', totals['clicks'] ?? 0),
        ],
      'payments' => [
          MapEntry('Awaiting review',
              payments.where((p) => p['status'] == 'under_review').length),
          MapEntry('Approved',
              payments.where((p) => p['status'] == 'approved').length),
          MapEntry('Rejected',
              payments.where((p) => p['status'] == 'rejected').length),
          MapEntry('Total submissions', payments.length),
        ],
      _ => [
          MapEntry('Customers', overview?['users_total'] ?? 0),
          MapEntry('Approved', overview?['users_approved'] ?? 0),
          MapEntry('Generated assets', totals['generated_assets'] ?? 0),
          MapEntry('Published posts', totals['published'] ?? 0),
        ],
    };
  }

  String get adminTitle => switch (widget.adminSection) {
        'media' => 'AI & media usage',
        'publishing' => 'Publishing operations',
        'analytics' => 'Customer analytics',
        'payments' => 'Payment review',
        _ => 'Customer overview',
      };

  String get adminDescription => switch (widget.adminSection) {
        'media' => 'Recorded generation activity by provider and model.',
        'publishing' =>
          'Channel health, upcoming workload, and publishing outcomes.',
        'analytics' =>
          'Platform performance from the latest collected sample for each post.',
        'payments' =>
          'Review submitted payment references and approve customer access.',
        _ =>
          'Adoption, workspace usage, and social performance across customers.',
      };

  IconData get adminIcon => switch (widget.adminSection) {
        'media' => LucideIcons.bot,
        'publishing' => LucideIcons.clock3,
        'analytics' => LucideIcons.chartColumn,
        'payments' => LucideIcons.shieldCheck,
        _ => LucideIcons.activity,
      };

  Widget _adminTable(BuildContext context, String title, String description,
      List<String> headings, List<List<String>> rows, String emptyText) {
    final scheme = Theme.of(context).colorScheme;
    return VaeGlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(description,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
        const SizedBox(height: 18),
        if (rows.isEmpty)
          Text(emptyText,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12))
        else
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: DecoratedBox(
              decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(15)),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStatePropertyAll(
                      scheme.primary.withValues(alpha: .08)),
                  columnSpacing: 22,
                  headingTextStyle: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface),
                  dataTextStyle: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 11,
                      color: scheme.onSurfaceVariant),
                  columns: [
                    for (final heading in headings)
                      DataColumn(label: Text(heading))
                  ],
                  rows: [
                    for (final row in rows)
                      DataRow(cells: [
                        for (final value in row) DataCell(Text(value))
                      ])
                  ],
                ),
              ),
            ),
          ),
      ]),
    );
  }

  Widget adminBody(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final media = widget.adminSection == 'media';
    final publishing = widget.adminSection == 'publishing';
    final paymentReview = widget.adminSection == 'payments';
    final models = (overview?['models'] as List? ?? const [])
        .map((raw) => Map<String, dynamic>.from(raw as Map))
        .toList();
    final platforms = (overview?['platforms'] as List? ?? const [])
        .map((raw) => Map<String, dynamic>.from(raw as Map))
        .toList();
    final users = (overview?['users'] as List? ?? const [])
        .map((raw) => Map<String, dynamic>.from(raw as Map))
        .toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: scheme.primary.withValues(alpha: .17)),
          gradient: LinearGradient(colors: [
            scheme.primary.withValues(alpha: .20),
            scheme.surface.withValues(alpha: .88),
          ]),
          boxShadow: const [
            BoxShadow(color: Color(0x33000000), blurRadius: 35)
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(adminIcon, size: 14, color: scheme.primary),
            const SizedBox(width: 7),
            Text('VAE ADMINISTRATION',
                style: TextStyle(
                    color: scheme.primary,
                    fontFamily: 'JetBrainsMono',
                    fontSize: 10,
                    letterSpacing: 1.4)),
          ]),
          const SizedBox(height: 12),
          Text(adminTitle, style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 10),
          Text(adminDescription,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
          const SizedBox(height: 16),
          if (!paymentReview && overview?['generated_at'] != null)
            Text('Updated ${overview!['generated_at']} · Operational KPIs',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
              onPressed: busy ? null : load,
              icon: const Icon(LucideIcons.refreshCw, size: 15),
              label: Text(
                  paymentReview ? 'Refresh submissions' : 'Refresh report')),
        ]),
      ),
      const SizedBox(height: 20),
      LayoutBuilder(builder: (context, constraints) {
        final width = (constraints.maxWidth - 12) / 2;
        return Wrap(spacing: 12, runSpacing: 12, children: [
          for (var i = 0; i < adminMetrics.length; i++)
            SizedBox(
              width: width,
              child: VaeGlassCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.topRight,
                        child: Text('${i + 1}'.padLeft(2, '0'),
                            style: TextStyle(
                                color: scheme.primary.withValues(alpha: .7),
                                fontFamily: 'JetBrainsMono',
                                fontSize: 11)),
                      ),
                      Text(adminMetrics[i].key,
                          style: TextStyle(
                              color: scheme.onSurfaceVariant, fontSize: 12)),
                      const SizedBox(height: 18),
                      Text('${adminMetrics[i].value}',
                          style: Theme.of(context).textTheme.displaySmall),
                    ]),
              ),
            ),
        ]);
      }),
      const SizedBox(height: 24),
      if (paymentReview)
        VaeGlassCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${payments.length} submissions',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 14),
            if (payments.isEmpty)
              Text('No payment submissions',
                  style: TextStyle(color: scheme.onSurfaceVariant)),
            for (final payment in payments)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(LucideIcons.shieldCheck, color: scheme.primary),
                title: Text('${payment['display_name'] ?? 'Account'}'),
                subtitle: Text(
                    '${payment['amount']} ${payment['currency'] ?? ''} · ${payment['utr_reference'] ?? 'No payment reference'}'),
                trailing: PopupMenuButton<String>(
                  tooltip: 'Review payment',
                  enabled: !busy &&
                      payment['status'] != 'approved' &&
                      payment['status'] != 'rejected',
                  onSelected: (decision) => review(payment, decision),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'approve', child: Text('Approve')),
                    PopupMenuItem(value: 'reject', child: Text('Reject')),
                  ],
                ),
              ),
          ]),
        )
      else ...[
        if (media)
          _adminTable(
              context,
              'Provider & model activity',
              'Recorded campaign runs and generated media assets.',
              const [
                'Provider / model',
                'Activity',
                'Count',
                'Failed',
                'Recorded tokens',
                'Metered runs'
              ],
              [
                for (final item in models)
                  [
                    '${item['provider'] ?? ''} / ${item['model'] ?? ''}',
                    item['kind'] == 'llm' ? 'LLM runs' : 'Media assets',
                    '${item['requests'] ?? 0}',
                    '${item['failed'] ?? 0}',
                    item['kind'] == 'llm'
                        ? '${(item['prompt_tokens'] ?? 0) + (item['completion_tokens'] ?? 0)}'
                        : 'Not metered',
                    item['kind'] == 'llm'
                        ? '${item['metered_runs'] ?? 0} / ${item['requests'] ?? 0}'
                        : '—',
                  ],
              ],
              'No recorded generation activity yet.')
        else
          _adminTable(
              context,
              publishing
                  ? 'Channels & schedules'
                  : 'Social platform performance',
              'Impressions are platform-reported views, not website visits.',
              publishing
                  ? const [
                      'Platform',
                      'Connected / total',
                      'Scheduled',
                      'Queued',
                      'Published',
                      'Publish failures',
                      'Schedule failures'
                    ]
                  : const [
                      'Platform',
                      'Connected / total',
                      'Scheduled',
                      'Queued',
                      'Published',
                      'Impressions',
                      'Engagements',
                      'Clicks'
                    ],
              [
                for (final item in platforms)
                  [
                    '${item['platform'] ?? ''}',
                    '${item['connected'] ?? 0} / ${item['channels'] ?? 0}',
                    '${item['scheduled'] ?? 0}',
                    '${item['queued'] ?? 0}',
                    '${item['published'] ?? 0}',
                    if (publishing) ...[
                      '${item['failed'] ?? 0}',
                      '${item['schedule_failed'] ?? 0}',
                    ] else ...[
                      '${item['impressions'] ?? 0}',
                      '${item['engagements'] ?? 0}',
                      '${item['clicks'] ?? 0}',
                    ],
                  ],
              ],
              'No connected channels or platform activity yet.'),
        const SizedBox(height: 24),
        _adminTable(
            context,
            media ? 'Customer generation usage' : 'Customer usage',
            'Workspace totals across each customer’s memberships.',
            media
                ? const [
                    'Customer',
                    'Status',
                    'LLM runs',
                    'Generated assets',
                    'Recorded tokens'
                  ]
                : const [
                    'Customer',
                    'Status',
                    'Assets',
                    'Channels',
                    'Scheduled',
                    'Published',
                    'Engagements'
                  ],
            [
              for (final user in users)
                [
                  '${user['display_name'] ?? 'Account'}',
                  '${user['account_status'] ?? ''}'.replaceAll('_', ' '),
                  if (media) ...[
                    '${user['generation_runs'] ?? 0}',
                    '${user['generated_assets'] ?? 0}',
                    '${(user['prompt_tokens'] ?? 0) + (user['completion_tokens'] ?? 0)}',
                  ] else ...[
                    '${user['assets'] ?? 0}',
                    '${user['channels'] ?? 0}',
                    '${user['scheduled'] ?? 0}',
                    '${user['published'] ?? 0}',
                    '${user['engagements'] ?? 0}',
                  ],
                ],
            ],
            'No customer usage yet.'),
      ],
    ]);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: Colors.transparent,
      appBar:
          widget.admin ? null : AppBar(title: const Text('Brand knowledge')),
      body: VaeScaffold(children: [
        if (busy) const LinearProgressIndicator(),
        if (error != null)
          Text(error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (notice != null) Semantics(liveRegion: true, child: Text(notice!)),
        if (widget.admin && widget.state.user?.isAdmin == true) ...[
          if (overview == null && !busy)
            VaeEmptyState('Reporting is unavailable',
                'Refresh to load the latest administrator report.'),
          if (overview != null) adminBody(context),
        ] else if (widget.admin) ...[
          const VaeEmptyState('Admin access required',
              'This account does not have access to operational tools.'),
        ] else ...[
          const VaePageHeader(
              'Brand knowledge', 'Your brand and source documents.'),
          ExpansionTile(title: const Text('Add a brand'), children: [
            Form(
                key: brandForm,
                child: Column(children: [
                  TextFormField(
                      controller: brandName,
                      validator: requiredText,
                      decoration:
                          const InputDecoration(labelText: 'Brand name')),
                  const SizedBox(height: 16),
                  TextFormField(
                      controller: brandDescription,
                      validator: requiredText,
                      minLines: 2,
                      maxLines: 5,
                      decoration: const InputDecoration(
                          labelText: 'Brand description')),
                  const SizedBox(height: 16),
                  VaePrimaryButton('Save brand',
                      busy: busy, onPressed: createBrand),
                ]))
          ]),
          const SizedBox(height: 16),
          ...widget.state.brands.map((b) =>
              ListTile(title: Text(b.name), subtitle: Text(b.description))),
          if (widget.state.documents.isEmpty)
            const VaeEmptyState('No sources yet',
                'Add a source below to ground your creative work.'),
          const SizedBox(height: 24),
          VaeGlassCard(
              child: Form(
                  key: sourceForm,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Add a source',
                            style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 16),
                        TextFormField(
                            controller: sourceTitle,
                            validator: requiredText,
                            decoration: const InputDecoration(
                                labelText: 'Source title')),
                        const SizedBox(height: 16),
                        TextFormField(
                            controller: sourceContent,
                            validator: requiredText,
                            minLines: 4,
                            maxLines: 10,
                            decoration: const InputDecoration(
                                labelText: 'Source text',
                                hintText:
                                    'Paste brand guidelines, product notes, or Markdown…')),
                        const SizedBox(height: 16),
                        VaePrimaryButton('Add source',
                            busy: busy, onPressed: ingest),
                      ]))),
          const SizedBox(height: 24),
          VaeGlassCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                TextField(
                    controller: query,
                    decoration: const InputDecoration(
                        labelText: 'Ask your brand knowledge')),
                const SizedBox(height: 16),
                VaePrimaryButton('Search sources',
                    busy: busy, onPressed: search),
                if (searched && citations.isEmpty)
                  const Text(
                      'No matching sources. Try another question or add a source.'),
                ...citations.map((c) => ListTile(
                    title: Text(c['document_title'] as String? ?? 'Source'),
                    subtitle: Text(c['excerpt'] as String? ?? ''))),
              ])),
          const SizedBox(height: 24),
          ...widget.state.documents.map(
              (d) => ListTile(title: Text(d.title), subtitle: Text(d.status))),
        ],
      ]));
}
