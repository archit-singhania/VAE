import 'package:flutter/material.dart';
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
          MapEntry('Input tokens', totals['prompt_tokens'] ?? 0),
          MapEntry('Output tokens', totals['completion_tokens'] ?? 0),
        ],
      'publishing' => [
          MapEntry('Channels', totals['channels'] ?? 0),
          MapEntry('Upcoming schedules', totals['scheduled'] ?? 0),
          MapEntry('Published posts', totals['published'] ?? 0),
          MapEntry('Failed jobs', totals['failed'] ?? 0),
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

  Widget adminBody(BuildContext context) {
    final detailItems = widget.adminSection == 'payments'
        ? const []
        : widget.adminSection == 'media'
            ? (overview?['models'] as List? ?? const [])
            : (overview?['platforms'] as List? ?? const []);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      VaePageHeader(adminTitle,
          'Live operational reporting across customers and workspaces.'),
      Wrap(
          spacing: 12,
          runSpacing: 12,
          children: adminMetrics
              .map((entry) => SizedBox(
                  width: 230,
                  child: VaeMetricCard(entry.key, '${entry.value}')))
              .toList()),
      const SizedBox(height: 24),
      if (detailItems.isNotEmpty)
        VaeGlassCard(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              Text(
                  widget.adminSection == 'media'
                      ? 'Provider & model activity'
                      : 'Platform performance',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              ...detailItems.map((raw) {
                final item = Map<String, dynamic>.from(raw as Map);
                final title = widget.adminSection == 'media'
                    ? '${item['provider'] ?? 'Provider'} · ${item['model'] ?? 'Model'}'
                    : '${item['platform'] ?? 'Platform'}';
                final subtitle = widget.adminSection == 'media'
                    ? '${item['requests'] ?? 0} requests · ${item['failed'] ?? 0} failed'
                    : '${item['channels'] ?? 0} channels · ${item['published'] ?? 0} published · ${item['engagements'] ?? 0} engagements';
                return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(title),
                    subtitle: Text(subtitle));
              })
            ])),
      const SizedBox(height: 24),
      if (widget.adminSection == 'payments') ...[
        Text('Payment review',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        if (payments.isEmpty)
          const VaeEmptyState('No payment submissions',
              'New manual payment reviews will appear here.'),
        ...payments.map((p) => ListTile(
            title: Text(p['display_name'] as String? ?? 'Account'),
            subtitle: Text('${p['amount']} · ${p['status']}'),
            trailing: PopupMenuButton<String>(
                enabled: !busy,
                onSelected: (v) => review(p, v),
                itemBuilder: (_) => const [
                      PopupMenuItem(value: 'approve', child: Text('Approve')),
                      PopupMenuItem(value: 'reject', child: Text('Reject'))
                    ]))),
      ],
      if (widget.adminSection != 'overview') ...[
        Text('Customer usage',
            style: Theme.of(context).textTheme.headlineSmall),
        ...(overview?['users'] as List? ?? const []).map((raw) {
          final user = Map<String, dynamic>.from(raw as Map);
          return ExpansionTile(
              title: Text(user['display_name'] as String? ?? 'Account'),
              subtitle: Text(user['account_status'] as String? ?? ''),
              children: user.entries
                  .where((entry) => entry.value is num)
                  .map((entry) => ListTile(
                      title: Text(entry.key.replaceAll('_', ' ')),
                      trailing: Text('${entry.value}')))
                  .toList());
        }),
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
