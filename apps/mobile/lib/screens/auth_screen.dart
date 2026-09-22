import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/aevra_theme.dart';
import '../widgets/aevra_logo.dart';
import '../widgets/depth.dart';
import '../widgets/landing_video.dart';
import '../widgets/shader_background.dart';

/// The mobile counterpart of the web app's `.live-auth` screen — same
/// shader background + glass auth card, same login/register fields.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.state});

  final AppState state;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _org = TextEditingController();
  String _accountType = 'creator';
  final _utr = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _org.dispose();
    _utr.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (isLogin) {
      await widget.state.login(_email.text.trim(), _password.text);
    } else {
      await widget.state.register(
        email: _email.text.trim(),
        password: _password.text,
        displayName: _name.text.trim(),
        organizationName: _org.text.trim(),
        workspaceName: 'Content Studio',
        accountType: _accountType,
        timezone: DateTime.now().timeZoneName,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AevraColors.bg,
      body: Stack(
        children: [
          const Positioned.fill(
              child: RepaintBoundary(child: ShaderBackground())),
          // The original MOV artwork is optional and never blocks the first
          // frame. LandingVideo fades in only after local codec support is
          // confirmed; ShaderBackground remains the free fallback.
          const Positioned.fill(child: LandingVideo()),
          SafeArea(
            child: AnimatedBuilder(
              animation: widget.state,
              builder: (context, _) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(AevraSpace.lg,
                      AevraSpace.xxl, AevraSpace.lg, AevraSpace.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AevraWordmark(markSize: 30, fontSize: 17),
                      const SizedBox(height: AevraSpace.xxl),
                      Text('CAMPAIGN INTELLIGENCE', style: AevraType.eyebrow()),
                      const SizedBox(height: AevraSpace.sm),
                      Text(
                        'Every campaign,\nas sharp as your\nbest work.',
                        style: AevraType.display(34),
                      ),
                      const SizedBox(height: AevraSpace.md),
                      const Text(
                        'Approved brand knowledge in. Evidence-backed, human-approved content out. Nothing publishes without a person saying yes.',
                        style: TextStyle(
                            fontSize: 13.5,
                            height: 1.6,
                            color: AevraColors.textSoft),
                      ),
                      const SizedBox(height: AevraSpace.lg),
                      // Three proof points, set as a mono rail. On a phone
                      // these do the job the web hero's feature column does.
                      ...[
                        'Grounded in your own sources',
                        'Human approval on every variant',
                        'One account, every channel',
                      ].map(
                        (point) => Padding(
                          padding: const EdgeInsets.only(bottom: AevraSpace.xs),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 4,
                                height: 4,
                                margin: const EdgeInsets.only(
                                    top: 6, right: AevraSpace.sm),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AevraColors.accent,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  point,
                                  style: const TextStyle(
                                      fontSize: 12, color: AevraColors.muted),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AevraSpace.xl),
                      // The one surface on this screen, so it gets the top
                      // tier — but no tilt. A tap-down tilt recogniser here
                      // would enter the gesture arena against every TextField
                      // inside it, which risks taps not reliably focusing a
                      // field. Depth on a form isn't worth that.
                      GlassSurface(
                        elevation: GlassElevation.lifted,
                        radius: AevraRadius.lg,
                        padding: const EdgeInsets.all(AevraSpace.lg),
                        adaptive: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _Tab(
                                    label: 'Sign in',
                                    active: isLogin,
                                    onTap: () =>
                                        setState(() => isLogin = true)),
                                const SizedBox(width: AevraSpace.lg),
                                _Tab(
                                    label: 'Get started',
                                    active: !isLogin,
                                    onTap: () =>
                                        setState(() => isLogin = false)),
                              ],
                            ),
                            const SizedBox(height: AevraSpace.lg),
                            Text(
                              isLogin
                                  ? 'Welcome back'
                                  : 'Create your VAE account',
                              style: AevraType.display(21),
                            ),
                            const SizedBox(height: AevraSpace.md),
                            if (widget.state.error != null) ...[
                              _ErrorBanner(message: widget.state.error!),
                              const SizedBox(height: AevraSpace.sm),
                            ],
                            if (widget.state.paymentPending &&
                                widget.state.paymentInfo != null) ...[
                              Text('Payment verification',
                                  style: AevraType.eyebrow()),
                              const SizedBox(height: AevraSpace.sm),
                              Text(
                                  'Scan with GPay, Paytm, BHIM, or any UPI app.',
                                  style: const TextStyle(
                                      color: AevraColors.textSoft)),
                              if (widget.state.paymentInfo!.qrUrl.isNotEmpty)
                                Image.network(widget.state.paymentInfo!.qrUrl,
                                    width: 160, height: 160),
                              Text(
                                  '${widget.state.paymentInfo!.amount} ${widget.state.paymentInfo!.currency}'),
                              Text(widget.state.paymentInfo!.upiId),
                              _Field(
                                  label: 'UTR / transaction reference',
                                  controller: _utr),
                              const SizedBox(height: AevraSpace.sm),
                              SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                      onPressed: widget.state.loading
                                          ? null
                                          : () => widget.state
                                              .submitPayment(_utr.text.trim()),
                                      child:
                                          const Text('Submit payment proof'))),
                              const SizedBox(height: AevraSpace.md),
                            ] else if (!isLogin) ...[
                              _Field(label: 'Your name', controller: _name),
                              const SizedBox(height: AevraSpace.sm),
                              _Field(
                                  label: 'Product or brand name',
                                  controller: _org),
                              const SizedBox(height: AevraSpace.sm),
                              DropdownButtonFormField<String>(
                                initialValue: _accountType,
                                decoration: const InputDecoration(
                                    labelText: 'Account type'),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'creator', child: Text('Creator')),
                                  DropdownMenuItem(
                                      value: 'business',
                                      child: Text('Business')),
                                ],
                                onChanged: (value) => setState(
                                    () => _accountType = value ?? 'creator'),
                              ),
                              const SizedBox(height: AevraSpace.sm),
                            ],
                            _Field(
                                label: 'Email',
                                controller: _email,
                                keyboardType: TextInputType.emailAddress),
                            const SizedBox(height: AevraSpace.sm),
                            _Field(
                                label: 'Password',
                                controller: _password,
                                obscure: true),
                            const SizedBox(height: AevraSpace.lg),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed:
                                    widget.state.loading ? null : _submit,
                                child: widget.state.loading
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AevraColors.accentInk),
                                      )
                                    : Text(isLogin ? 'Sign in' : 'Get started'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      // Opaque hit target: without this the gesture only lands on the glyphs
      // themselves, and the gaps between letters do nothing.
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.1,
              color: active ? AevraColors.text : AevraColors.muted,
            ),
          ),
          const SizedBox(height: AevraSpace.xs),
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            height: 2,
            width: active ? 28 : 0,
            decoration: BoxDecoration(
              color: AevraColors.accent,
              borderRadius: BorderRadius.circular(AevraRadius.pill),
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatefulWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.obscure = false,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final bool obscure;
  final TextInputType? keyboardType;

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  late bool hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    // Field chrome now comes entirely from `inputDecorationTheme`, so a
    // change to field radius, fill or focus colour lands here and in the
    // command palette at the same time instead of drifting apart.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label.toUpperCase(),
            style: AevraType.eyebrow(color: AevraColors.muted2)),
        const SizedBox(height: AevraSpace.xs),
        TextField(
          controller: widget.controller,
          obscureText: hidden,
          keyboardType: widget.keyboardType,
          decoration: InputDecoration(
            suffixIcon: widget.obscure
                ? IconButton(
                    tooltip: hidden ? 'Show password' : 'Hide password',
                    icon: Icon(hidden
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => hidden = !hidden),
                  )
                : null,
          ),
          cursorColor: AevraColors.accent,
          style: const TextStyle(fontSize: 13.5, color: AevraColors.text),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AevraSpace.sm, vertical: 10),
      decoration: BoxDecoration(
        color: AevraColors.rose.withValues(alpha: 0.09),
        border: Border.all(color: AevraColors.rose.withValues(alpha: 0.22)),
        borderRadius: BorderRadius.circular(AevraRadius.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 15, color: AevraColors.rose),
          const SizedBox(width: AevraSpace.xs),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                  fontSize: 11.5, height: 1.45, color: AevraColors.rose),
            ),
          ),
        ],
      ),
    );
  }
}
