import 'package:flutter/material.dart';
import '../state/app_state.dart';
import 'vae_ui.dart';

class VaeProfileSheet extends StatefulWidget {
  const VaeProfileSheet(
      {super.key, required this.state, required this.onSignOut});
  final AppState state;
  final VoidCallback onSignOut;
  @override
  State<VaeProfileSheet> createState() => _VaeProfileSheetState();
}

class _VaeProfileSheetState extends State<VaeProfileSheet> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.state.user?.displayName);
  late final email = TextEditingController(text: widget.state.user?.email);
  late final brand = TextEditingController(text: widget.state.user?.brandName);
  final current = TextEditingController(), password = TextEditingController();
  late String? avatar = widget.state.user?.avatarUrl;
  bool busy = false;
  String? error, notice;
  @override
  void dispose() {
    for (final c in [name, email, brand, current, password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> upload() async {
    final s = widget.state;
    if (s.token == null || s.workspace == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await s.client
          .pickAndUpload(s.token!, s.workspace!.id, imagesOnly: true);
      if (result != null && mounted) {
        final updated = await s.client.updateProfile(s.token!, {
          'display_name': name.text.trim(),
          'email': email.text.trim(),
          'brand_name': brand.text.trim(),
          'avatar_url': result.downloadUrl,
          'account_type': s.user!.accountType
        });
        s.updateUser(updated);
        setState(() {
          avatar = result.downloadUrl;
          notice = 'Profile picture updated.';
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    final s = widget.state;
    if (s.token == null || s.user == null) return;
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      final updated = await s.client.updateProfile(s.token!, {
        'display_name': name.text.trim(),
        'email': email.text.trim(),
        'brand_name': brand.text.trim(),
        'avatar_url': avatar,
        'account_type': s.user!.accountType
      });
      s.updateUser(updated);
      if (password.text.isNotEmpty) {
        await s.client.changePassword(s.token!, current.text, password.text);
        current.clear();
        password.clear();
      }
      if (mounted) setState(() => notice = 'Profile saved.');
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
          child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Material(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(32),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                  key: form,
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [
                          Expanded(
                              child: Text('Profile',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium)),
                          IconButton(
                              tooltip: 'Close profile',
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close))
                        ]),
                        Center(
                            child: CircleAvatar(
                                radius: 36,
                                backgroundImage: avatar == null
                                    ? null
                                    : NetworkImage(avatar!),
                                child: avatar == null
                                    ? const Icon(Icons.person_outline)
                                    : null)),
                        TextButton(
                            onPressed: busy ? null : upload,
                            child: const Text('Upload profile image')),
                        TextFormField(
                            controller: name,
                            decoration: const InputDecoration(
                                labelText: 'Display name'),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Enter a name.'
                                : null),
                        const SizedBox(height: 16),
                        TextFormField(
                            controller: email,
                            keyboardType: TextInputType.emailAddress,
                            decoration:
                                const InputDecoration(labelText: 'Email'),
                            validator: (v) => v == null || !v.contains('@')
                                ? 'Enter a valid email.'
                                : null),
                        const SizedBox(height: 16),
                        TextFormField(
                            controller: brand,
                            decoration: const InputDecoration(
                                labelText: 'Product or brand')),
                        const SizedBox(height: 24),
                        TextFormField(
                            controller: current,
                            obscureText: true,
                            decoration: const InputDecoration(
                                labelText: 'Current password'),
                            validator: (v) => password.text.isNotEmpty &&
                                    (v == null || v.isEmpty)
                                ? 'Enter your current password.'
                                : null),
                        const SizedBox(height: 16),
                        TextFormField(
                            controller: password,
                            obscureText: true,
                            decoration: const InputDecoration(
                                labelText: 'New password (optional)'),
                            validator: (v) =>
                                v != null && v.isNotEmpty && v.length < 8
                                    ? 'Use at least 8 characters.'
                                    : null),
                        const SizedBox(height: 16),
                        if (error != null)
                          Semantics(
                              liveRegion: true,
                              child: Text(error!,
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .error))),
                        if (notice != null)
                          Semantics(liveRegion: true, child: Text(notice!)),
                        VaePrimaryButton('Save profile',
                            busy: busy, onPressed: save),
                        TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              widget.onSignOut();
                            },
                            child: const Text('Sign out')),
                        TextButton(
                            onPressed: () => showDialog<void>(
                                context: context,
                                builder: (context) => AlertDialog(
                                        title: const Text('Account deletion'),
                                        content: const SelectableText(
                                            'To request deletion, open the Account deletion page from the VAE web sign-in screen. You will find the account verification and deletion instructions there.'),
                                        actions: [
                                          TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              child: const Text('Close'))
                                        ])),
                            child: const Text('Delete account')),
                      ])),
            )),
      ));
}
