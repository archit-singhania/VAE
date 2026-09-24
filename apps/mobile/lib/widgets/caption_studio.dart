import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../api/models.dart';

class CaptionStudio extends StatefulWidget {
  const CaptionStudio(
      {super.key, required this.state, this.asset, this.initial = ''});
  final AppState state;
  final MediaAsset? asset;
  final String initial;
  @override
  State<CaptionStudio> createState() => _CaptionStudioState();
}

class _CaptionStudioState extends State<CaptionStudio> {
  late final text = TextEditingController(
      text: widget.asset?.caption.isNotEmpty == true
          ? widget.asset!.caption
          : widget.initial.isNotEmpty
              ? widget.initial
              : widget.state.draftCaption);
  bool busy = false;
  String? error;
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Future<void> prepare(bool generate) async {
    final s = widget.state;
    if (s.token == null || s.workspace == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final value = generate
          ? await s.client.generateText(
              s.token!,
              s.workspace!.id,
              'Write a social caption with relevant hashtags. Context: ${widget.asset?.prompt ?? s.draftPrompt}. Existing copy: ${text.text}',
              (_) {})
          : await s.client.pickCaption(s.token!, s.workspace!.id);
      if (value != null && mounted) {
        final use = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
                    title: const Text('Review caption'),
                    content: SingleChildScrollView(child: Text(value)),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Discard')),
                      FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Use caption'))
                    ]));
        if (use == true) text.text = value;
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    final s = widget.state;
    if (s.token == null || s.workspace == null) return;
    setState(() => busy = true);
    try {
      if (widget.asset != null) {
        final asset = await s.client.saveAssetCaption(
            s.token!, s.workspace!.id, widget.asset!.id, text.text);
        s.assets = s.assets.map((a) => a.id == asset.id ? asset : a).toList();
      }
      s.draftCaption = text.text;
      if (mounted) Navigator.pop(context, text.text);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = '$e';
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: const Text('Caption & hashtags'),
          content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (widget.asset != null) Text(widget.asset!.filename),
                TextField(
                    controller: text,
                    maxLength: 30000,
                    minLines: 3,
                    maxLines: 8,
                    decoration: const InputDecoration(
                        labelText: 'Write or edit your caption')),
                Wrap(spacing: 8, children: [
                  TextButton.icon(
                      onPressed: busy ? null : () => prepare(true),
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Generate')),
                  TextButton.icon(
                      onPressed: busy ? null : () => prepare(false),
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Import PDF / TXT / MD'))
                ]),
                const Text(
                    'Text PDFs only, up to 20 pages / 2 MB. Review imported or generated copy before using it.'),
                if (busy) const LinearProgressIndicator(),
                if (error != null) Text(error!),
              ]))),
          actions: [
            TextButton(
                onPressed: busy ? null : () => Navigator.pop(context),
                child: const Text('Later')),
            FilledButton(
                onPressed: busy ? null : save,
                child: const Text('Save caption'))
          ]);
}
