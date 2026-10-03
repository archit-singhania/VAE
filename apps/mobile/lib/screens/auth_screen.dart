import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/aevra_theme.dart';
import '../widgets/aevra_logo.dart';
import '../widgets/depth.dart';
import '../widgets/landing_video.dart';
import '../widgets/shader_background.dart';

/// Brand-aligned account entry with a portrait media background and a focused
/// form that adapts from compact phones to a wider two-column composition.
class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.state,
    this.initialAdminPortal = false,
    this.onToggleTheme,
  });

  final AppState state;
  final bool initialAdminPortal;
  final VoidCallback? onToggleTheme;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  bool _adminPortal = false;
  final GlobalKey _formKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _org = TextEditingController();
  String _accountType = 'creator';
  final _utr = TextEditingController();

  @override
  void initState() {
    super.initState();
    _adminPortal = widget.initialAdminPortal;
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _org.dispose();
    _utr.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_email.text.contains('@') ||
        _password.text.length < 8 ||
        (!isLogin && _name.text.trim().isEmpty)) {
      widget.state.reportError(
          'Enter a valid email, a password of at least 8 characters, and your name when registering.');
      return;
    }
    if (isLogin) {
      await widget.state.login(_email.text.trim(), _password.text);
      if (_adminPortal &&
          widget.state.user != null &&
          widget.state.user?.isAdmin != true) {
        await widget.state.signOut();
        widget.state
            .reportError('Use an administrator account for this portal.');
      }
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Theme(
      data: _adminPortal
          ? (dark ? AevraTheme.adminDark : AevraTheme.adminLight)
          : Theme.of(context),
      child: LayoutBuilder(builder: _buildPortal),
    );
  }

  void _showForm() {
    final target = _formKey.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(target,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic);
    }
  }

  void _switchPortal() {
    setState(() {
      _adminPortal = !_adminPortal;
      isLogin = true;
      widget.state.error = null;
    });
    if (_scrollController.hasClients) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _scrollController.jumpTo(0);
      } else {
        _scrollController.animateTo(0,
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic);
      }
    }
  }

  Widget _buildPortal(BuildContext context, BoxConstraints constraints) {
    final colors = Theme.of(context).colorScheme;
    final width = constraints.maxWidth;
    final compact = width < 700;
    final narrow = width < 360;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-1, -.8),
            radius: 1.3,
            colors: [
              colors.primary.withValues(alpha: .075),
              Colors.transparent
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                    compact ? 16 : 32, 12, compact ? 16 : 32, 0),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: GlassChrome(
                      radius: 30,
                      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: AevraWordmark(
                                    markSize: 32,
                                    fontSize: 19,
                                    admin: _adminPortal),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: widget.onToggleTheme,
                            tooltip: 'Switch light / dark mode',
                            icon: Icon(
                                Theme.of(context).brightness == Brightness.light
                                    ? LucideIcons.moon
                                    : LucideIcons.sun,
                                size: 18),
                          ),
                          IconButton(
                            onPressed: _switchPortal,
                            tooltip: _adminPortal
                                ? 'Switch to creator and business portal'
                                : 'Switch to administrator portal',
                            icon: Icon(
                                _adminPortal
                                    ? LucideIcons.sparkles
                                    : LucideIcons.shieldCheck,
                                size: 18),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: AnimatedBuilder(
                  animation: widget.state,
                  builder: (context, _) => SingleChildScrollView(
                    controller: _scrollController,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(narrow ? 16 : 24,
                        compact ? 20 : 36, narrow ? 16 : 24, 32),
                    child: _AuthLayout(
                      hero: _buildHero(context, compact: compact, width: width),
                      form: _buildForm(context, narrow: narrow),
                      footer: Padding(
                        padding: const EdgeInsets.only(top: 60),
                        child: _LandingStory(admin: _adminPortal),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openEntry({required bool register}) {
    setState(() => isLogin = _adminPortal || !register);
    WidgetsBinding.instance.addPostFrameCallback((_) => _showForm());
  }

  Widget _buildHero(BuildContext context,
      {required bool compact, required double width}) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: .10),
            blurRadius: 44,
            spreadRadius: -18,
            offset: const Offset(0, 22),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          children: [
            Positioned.fill(
              child: Theme(
                data: _adminPortal ? AevraTheme.adminDark : AevraTheme.dark,
                child: ShaderBackground(admin: _adminPortal),
              ),
            ),
            Positioned.fill(
                child: LandingVideo(admin: _adminPortal, portrait: compact)),
            // The middle of the frame is clear. Only copy receives a local
            // scrim, so the film retains its original colour in either theme.
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0, .35, .60, 1],
                      colors: [
                        const Color(0x19000000),
                        Colors.transparent,
                        const Color(0x26000000),
                        const Color(0xED07090E),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(width < 360 ? 22 : 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Theme(
                    data: _adminPortal ? AevraTheme.adminDark : AevraTheme.dark,
                    child: GlassChrome(
                      radius: 24,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                              _adminPortal
                                  ? LucideIcons.shieldCheck
                                  : LucideIcons.sparkles,
                              size: 14,
                              color: Colors.white),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _adminPortal
                                  ? 'VAE ADMINISTRATION'
                                  : 'CREATOR & BUSINESS',
                              style: AevraType.eyebrow(color: Colors.white)
                                  .copyWith(fontSize: 9, letterSpacing: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: compact ? 172 : 218),
                  Text(
                    _adminPortal
                        ? 'A clear view of\nyour operations.'
                        : 'Your ideas.\nBeautifully made.',
                    style: AevraType.display(
                      compact ? (width < 360 ? 34 : 40) : 48,
                      color: const Color(0xFFF8F7F5),
                      height: 1.08,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Text(
                      _adminPortal
                          ? 'Useful signals. Thoughtful decisions. One clear place to run the platform.'
                          : 'A beautifully connected space to create, publish, and grow your next idea.',
                      style: const TextStyle(
                          fontSize: 13, height: 1.6, color: Color(0xFFE0E2E7)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilledButton(
                        onPressed: () => _openEntry(register: !_adminPortal),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFF7F7FA),
                          foregroundColor: const Color(0xFF15141A),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 22, vertical: 15),
                          shape: const StadiumBorder(),
                        ),
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 6,
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(_adminPortal
                                ? 'Enter admin portal'
                                : 'Get started'),
                            const Icon(LucideIcons.arrowUpRight, size: 17),
                          ],
                        ),
                      ),
                      if (!_adminPortal)
                        TextButton(
                          onPressed: () => _openEntry(register: false),
                          style: TextButton.styleFrom(
                              foregroundColor: Colors.white),
                          child: const Text('I have an account'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: .18)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context, {required bool narrow}) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        // No tap/tilt recogniser here: fields must retain their focus gestures.
        GlassChrome(
          key: _formKey,
          dense: true,
          radius: 28,
          padding: EdgeInsets.all(narrow ? 20 : 26),
          borderColor: colors.primary.withValues(alpha: .22),
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_adminPortal) ...[
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colors.onSurface.withValues(alpha: .045),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                            child: _Tab(
                                label: 'Sign in',
                                active: isLogin,
                                onTap: () => setState(() => isLogin = true))),
                        const SizedBox(width: 4),
                        Expanded(
                            child: _Tab(
                                label: 'Create account',
                                active: !isLogin,
                                onTap: () => setState(() => isLogin = false))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                ] else ...[
                  Icon(LucideIcons.shieldCheck,
                      color: colors.primary, size: 26),
                  const SizedBox(height: 20),
                ],
                Text(
                  _adminPortal
                      ? 'Administrator sign in'
                      : isLogin
                          ? 'Welcome back.'
                          : 'Make room for your ideas.',
                  style: AevraType.display(29,
                      color: colors.onSurface, height: 1.12),
                ),
                const SizedBox(height: 10),
                Text(
                  _adminPortal
                      ? 'Secure access to customer operations.'
                      : isLogin
                          ? 'Your next creation starts here.'
                          : 'Create, publish, and understand in one place.',
                  style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 13,
                      height: 1.6),
                ),
                const SizedBox(height: 26),
                if (widget.state.error != null) ...[
                  _ErrorBanner(message: widget.state.error!),
                  const SizedBox(height: 16),
                ],
                if (!isLogin &&
                    widget.state.paymentPending &&
                    widget.state.paymentInfo != null) ...[
                  Text('Payment verification',
                      style: AevraType.eyebrow(color: colors.primary)),
                  const SizedBox(height: 12),
                  Text('Scan with GPay, Paytm, BHIM, or any UPI app.',
                      style: TextStyle(
                          color: colors.onSurfaceVariant, height: 1.5)),
                  if (widget.state.paymentInfo!.qrUrl.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Image.network(widget.state.paymentInfo!.qrUrl,
                          width: 160, height: 160),
                    ),
                  Text(
                      '${widget.state.paymentInfo!.amount} ${widget.state.paymentInfo!.currency}',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  SelectableText(widget.state.paymentInfo!.upiId),
                  const SizedBox(height: 20),
                  _Field(
                      label: 'UTR / transaction reference',
                      controller: _utr,
                      icon: LucideIcons.receipt),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: widget.state.loading
                          ? null
                          : () => widget.state.submitPayment(_utr.text.trim()),
                      child: const Text('Submit payment proof'),
                    ),
                  ),
                  const SizedBox(height: 24),
                ] else if (!isLogin) ...[
                  _Field(
                      label: 'Your name',
                      controller: _name,
                      icon: LucideIcons.userRound,
                      autofillHints: const [AutofillHints.name]),
                  const SizedBox(height: 18),
                  _Field(
                      label: 'Product or brand name',
                      controller: _org,
                      icon: LucideIcons.building2),
                  const SizedBox(height: 18),
                  Text('Account type', style: _fieldLabel(context)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _accountType,
                    isExpanded: true,
                    decoration: const InputDecoration(
                        prefixIcon:
                            Icon(LucideIcons.briefcaseBusiness, size: 18)),
                    items: const [
                      DropdownMenuItem(
                          value: 'creator', child: Text('Creator')),
                      DropdownMenuItem(
                          value: 'business', child: Text('Business')),
                    ],
                    onChanged: (value) =>
                        setState(() => _accountType = value ?? 'creator'),
                  ),
                  const SizedBox(height: 18),
                ],
                _Field(
                  label: 'Email address',
                  hint: 'you@example.com',
                  controller: _email,
                  icon: LucideIcons.mail,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                ),
                const SizedBox(height: 18),
                _Field(
                  label: 'Password',
                  hint:
                      isLogin ? 'Enter your password' : 'At least 8 characters',
                  controller: _password,
                  icon: LucideIcons.lockKeyhole,
                  obscure: true,
                  autofillHints: [
                    isLogin ? AutofillHints.password : AutofillHints.newPassword
                  ],
                  onSubmitted: widget.state.loading ? null : _submit,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: widget.state.loading ? null : _submit,
                    child: widget.state.loading
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: colors.onPrimary))
                        : Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 10,
                            runSpacing: 6,
                            children: [
                              Text(
                                  _adminPortal
                                      ? 'Sign in as administrator'
                                      : isLogin
                                          ? 'Enter your workspace'
                                          : 'Create account',
                                  textAlign: TextAlign.center),
                              const Icon(LucideIcons.arrowRight, size: 17),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: _switchPortal,
          style: TextButton.styleFrom(foregroundColor: colors.onSurfaceVariant),
          icon: Icon(
              _adminPortal ? LucideIcons.sparkles : LucideIcons.shieldCheck,
              size: 15),
          label: Text(
              _adminPortal ? 'Creator workspace' : 'Administrator access',
              textAlign: TextAlign.center),
        ),
      ],
    );
  }
}

class _LandingStory extends StatelessWidget {
  const _LandingStory({required this.admin});
  final bool admin;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final cards = admin
        ? const [
            (
              LucideIcons.layers,
              'See customer health clearly',
              'Follow adoption, workspace activity and publishing outcomes through operational KPIs.'
            ),
            (
              LucideIcons.brainCircuit,
              'Understand product usage',
              'Review aggregate generation activity, model usage and channel performance across customer workspaces.'
            ),
            (
              LucideIcons.shieldCheck,
              'Review with care',
              'Keep payment decisions and account operations in a dedicated administrator workspace.'
            ),
          ]
        : const [
            (
              LucideIcons.sparkles,
              'Make the idea tangible',
              'Turn a brief into images and social copy. Keep your brand references close and bring your own finished assets when you publish.'
            ),
            (
              LucideIcons.layers,
              'Give every visual a voice',
              'Write, generate, or import captions and hashtags. Pair them with an image whenever inspiration arrives.'
            ),
            (
              LucideIcons.calendarDays,
              'Publish with a clear view',
              'Connect your channels, review the complete post, and choose now or later. Follow delivery from one calendar.'
            ),
          ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
          admin
              ? 'CLARITY FOR THE PEOPLE BEHIND THE PLATFORM'
              : 'FROM A SPARK TO A STORY',
          style: AevraType.eyebrow(color: colors.primary)),
      const SizedBox(height: 10),
      Text(
          admin
              ? 'A considered view.\nEvery operation, in context.'
              : 'One thoughtful space.\nEvery part of your creative day.',
          style: AevraType.display(30, color: colors.onSurface, height: 1.15)),
      const SizedBox(height: 14),
      Text(
          admin
              ? 'Understand customer adoption, publishing health and payment review from one focused operations workspace.'
              : 'Create with intention. Pair the right words and visuals. Find a rhythm your audience can look forward to.',
          style: TextStyle(color: colors.onSurfaceVariant, height: 1.65)),
      const SizedBox(height: 24),
      LayoutBuilder(builder: (context, constraints) {
        final scaled = MediaQuery.textScalerOf(context).scale(14) / 14;
        final columns = constraints.maxWidth >= 900 && scaled < 1.4 ? 3 : 1;
        final cardWidth = (constraints.maxWidth - (columns - 1) * 16) / columns;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (var i = 0; i < cards.length; i++)
              SizedBox(
                width: cardWidth,
                child: GlassSurface(
                  radius: 24,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: .08),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(cards[i].$1,
                              color: colors.primary, size: 20),
                        ),
                        const Spacer(),
                        Text('${i + 1}'.padLeft(2, '0'),
                            style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontFamily: 'JetBrainsMono',
                                fontSize: 10)),
                      ]),
                      const SizedBox(height: 24),
                      Text(cards[i].$2,
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 10),
                      Text(cards[i].$3,
                          style: TextStyle(
                              color: colors.onSurfaceVariant, height: 1.6)),
                    ],
                  ),
                ),
              ),
          ],
        );
      }),
      const SizedBox(height: 12),
      GlassSurface(
        padding: const EdgeInsets.all(22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(admin ? LucideIcons.shieldCheck : LucideIcons.brainCircuit,
              color: colors.primary, size: 28),
          const SizedBox(height: 16),
          Text(
              admin
                  ? 'A CALMER WAY TO RUN THE PLATFORM'
                  : '13 TOOLS FOR A MORE INFORMED NEXT MOVE',
              style: AevraType.eyebrow(color: colors.primary)),
          const SizedBox(height: 10),
          Text(
              admin
                  ? 'Good operations start with useful signals.'
                  : 'Let your own history teach you.',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 10),
          Text(
              admin
                  ? 'Move between customer KPIs, AI and media usage, publishing analytics and payment review in a dedicated administrator workspace.'
                  : 'Explore content patterns, compare draft predictions, and check the quality of your data. Insights show their limits when there is not enough evidence.',
              style: TextStyle(color: colors.onSurfaceVariant, height: 1.5)),
        ]),
      ),
      const SizedBox(height: 32),
      Text(
          admin
              ? 'VAE · Thoughtful customer operations.'
              : 'VAE · Create. Publish. Understand.',
          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11)),
    ]);
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
      selected: active,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
            minimumSize: const Size(44, 44),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            backgroundColor: active
                ? Theme.of(context).colorScheme.surface
                : Colors.transparent,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            side: active
                ? BorderSide(color: Theme.of(context).dividerColor)
                : BorderSide.none,
            foregroundColor: active
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context).colorScheme.onSurfaceVariant),
        child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
      ));
}

TextStyle _fieldLabel(BuildContext context) => TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: Theme.of(context).colorScheme.onSurface,
    );

class _Field extends StatefulWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.obscure = false,
    this.keyboardType,
    this.icon,
    this.hint,
    this.autofillHints,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final bool obscure;
  final TextInputType? keyboardType;
  final IconData? icon;
  final String? hint;
  final Iterable<String>? autofillHints;
  final VoidCallback? onSubmitted;

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
        Text(widget.label, style: _fieldLabel(context)),
        const SizedBox(height: AevraSpace.xs),
        TextField(
          controller: widget.controller,
          obscureText: hidden,
          keyboardType: widget.keyboardType,
          autofillHints: widget.autofillHints,
          autocorrect: !widget.obscure &&
              widget.keyboardType != TextInputType.emailAddress,
          enableSuggestions: !widget.obscure,
          textInputAction: widget.onSubmitted == null
              ? TextInputAction.next
              : TextInputAction.done,
          onSubmitted:
              widget.onSubmitted == null ? null : (_) => widget.onSubmitted!(),
          decoration: InputDecoration(
            hintText: widget.hint,
            prefixIcon:
                widget.icon == null ? null : Icon(widget.icon, size: 18),
            suffixIcon: widget.obscure
                ? IconButton(
                    tooltip: hidden ? 'Show password' : 'Hide password',
                    icon: Icon(hidden ? LucideIcons.eye : LucideIcons.eyeOff,
                        size: 18),
                    onPressed: () => setState(() => hidden = !hidden),
                  )
                : null,
          ),
          cursorColor: Theme.of(context).colorScheme.primary,
          style: TextStyle(
              fontSize: 13.5, color: Theme.of(context).colorScheme.onSurface),
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
    final error = Theme.of(context).colorScheme.error;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AevraSpace.sm, vertical: 10),
      decoration: BoxDecoration(
        color: error.withValues(alpha: 0.09),
        border: Border.all(color: error.withValues(alpha: 0.22)),
        borderRadius: BorderRadius.circular(AevraRadius.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.circleAlert, size: 15, color: error),
          const SizedBox(width: AevraSpace.xs),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 11.5, height: 1.45, color: error),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthLayout extends StatelessWidget {
  const _AuthLayout(
      {required this.hero, required this.form, required this.footer});
  final Widget hero;
  final Widget form;
  final Widget footer;
  @override
  Widget build(BuildContext context) => Center(
          child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: LayoutBuilder(
          builder: (context, box) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (box.maxWidth >= 880)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: hero),
                    const SizedBox(width: 36),
                    Expanded(child: form),
                  ],
                )
              else ...[
                hero,
                const SizedBox(height: 24),
                form,
              ],
              footer,
            ],
          ),
        ),
      ));
}
