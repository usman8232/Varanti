import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show OAuthProvider;
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/error_messages.dart';
import '../../core/widgets/varanti_brand.dart';

enum _AuthChannel { email, phone }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  _AuthChannel _channel = _AuthChannel.email;
  bool _isSignUp = false;
  bool _otpSent = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _submitEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _errorMessage = null);

    final auth = ref.read(authProvider.notifier);
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      if (_isSignUp) {
        final signedInImmediately = await auth.signUpWithEmail(email, password);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                signedInImmediately
                    ? 'Account created. Welcome to Varanti.'
                    : 'Account created. Check your inbox to confirm your email before signing in.',
              ),
            ),
          );
        }
      } else {
        await auth.signInWithEmail(email, password);
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _errorMessage = ErrorMessages.friendly(
            e,
            fallback: _isSignUp
                ? "Couldn't create your account. Please try again."
                : "Couldn't sign you in. Please try again.",
          ),
        );
      }
    }
  }

  Future<void> _submitPhone() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _errorMessage = null);

    final auth = ref.read(authProvider.notifier);
    final phone = _phoneController.text.trim();

    try {
      if (!_otpSent) {
        await auth.sendPhoneOtp(phone);
        if (mounted) {
          setState(() => _otpSent = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Verification code sent via SMS.'),
            ),
          );
        }
      } else {
        await auth.verifyPhoneOtp(phone, _otpController.text.trim());
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _errorMessage = ErrorMessages.friendly(
            e,
            fallback: _otpSent
                ? "Couldn't verify that code. Please try again."
                : "Couldn't send a verification code right now.",
          ),
        );
      }
    }
  }

  Future<void> _signInOAuth(OAuthProvider provider, String label) async {
    setState(() => _errorMessage = null);
    try {
      await ref.read(authProvider.notifier).signInWithOAuthProvider(provider);
    } catch (e) {
      if (mounted) {
        setState(
          () => _errorMessage = ErrorMessages.friendly(
            e,
            fallback: "Couldn't sign in with $label right now.",
          ),
        );
      }
    }
  }

  void _setChannel(_AuthChannel next) {
    if (_channel == next) return;
    setState(() {
      _channel = next;
      _errorMessage = null;
      _otpSent = false;
      _otpController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final crimson = AppTheme.crimsonOf(context);
    final hairline = AppTheme.hairlineOf(context);
    final subtle = AppTheme.subtleSurfaceOf(context);
    final muted = AppTheme.mutedTextOf(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Minimal Brand Header
                      Center(
                        child: Container(
                          width: 72,
                          height: 72,
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: hairline),
                          ),
                          child: const VarantiMark(size: 42),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Center(child: VarantiWordmark(height: 24)),
                      const SizedBox(height: 8),
                      Text(
                        'Smart Receipt & Warranty Tracker',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: muted,
                        ),
                      ),
                      const SizedBox(height: 22),

                      // Minimal Hairline Auth Card
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: hairline),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Channel Switcher Pill (Email vs Phone)
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: subtle,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _ModePill(
                                      label: 'Email',
                                      icon: Icons.mail_outline_rounded,
                                      selected: _channel == _AuthChannel.email,
                                      onTap: () => _setChannel(_AuthChannel.email),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: _ModePill(
                                      label: 'Phone',
                                      icon: Icons.phone_outlined,
                                      selected: _channel == _AuthChannel.phone,
                                      onTap: () => _setChannel(_AuthChannel.phone),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            if (_errorMessage != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 11,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppTheme.brandCrimsonSoftDark
                                      : AppTheme.brandCrimsonSoftLight,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: crimson.withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.error_outline_rounded,
                                      size: 18,
                                      color: crimson,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: TextStyle(
                                          color: crimson,
                                          fontSize: 12,
                                          height: 1.35,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],

                            if (_channel == _AuthChannel.email)
                              ..._buildEmailForm(authState, muted)
                            else
                              ..._buildPhoneForm(authState, muted),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(child: Divider(color: hairline)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'OR CONTINUE WITH',
                              style: TextStyle(
                                color: muted,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: hairline)),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Social OAuth Pill Row (Google, Apple, Facebook)
                      Row(
                        children: [
                          Expanded(
                            child: _SocialPillButton(
                              label: 'Google',
                              icon: const SizedBox(
                                width: 18,
                                height: 18,
                                child: CustomPaint(painter: _GoogleMarkPainter()),
                              ),
                              disabled: authState.isLoading,
                              onTap: () => _signInOAuth(
                                OAuthProvider.google,
                                'Google',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _SocialPillButton(
                              label: 'Apple',
                              icon: Icon(
                                Icons.apple_rounded,
                                size: 20,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              disabled: authState.isLoading,
                              onTap: () => _signInOAuth(
                                OAuthProvider.apple,
                                'Apple',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _SocialPillButton(
                              label: 'Facebook',
                              icon: const Icon(
                                Icons.facebook_rounded,
                                size: 20,
                                color: Color(0xFF1877F2),
                              ),
                              disabled: authState.isLoading,
                              onTap: () => _signInOAuth(
                                OAuthProvider.facebook,
                                'Facebook',
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Guest Mode Pill CTA (SRS FR-AUTH-02)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.person_outline_rounded, size: 19),
                        label: const Text('Continue as Guest'),
                        onPressed: authState.isLoading
                            ? null
                            : () => ref.read(authProvider.notifier).enterGuestMode(),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Save receipts privately on this device. Sign in anytime to back them up.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: muted, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildEmailForm(AuthState authState, Color muted) {
    return [
      TextFormField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.email],
        decoration: const InputDecoration(
          labelText: 'Email Address',
          prefixIcon: Icon(Icons.mail_outline_rounded),
        ),
        validator: (val) {
          if (val == null || val.trim().isEmpty) return 'Enter your email';
          if (!val.contains('@')) return 'Enter a valid email';
          return null;
        },
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        textInputAction: TextInputAction.done,
        autofillHints: [
          _isSignUp ? AutofillHints.newPassword : AutofillHints.password,
        ],
        onFieldSubmitted: (_) => _submitEmail(),
        decoration: InputDecoration(
          labelText: 'Password',
          prefixIcon: const Icon(Icons.lock_outline_rounded),
          suffixIcon: IconButton(
            tooltip: _obscurePassword ? 'Show password' : 'Hide password',
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: muted,
            ),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        validator: (val) {
          if (val == null || val.trim().isEmpty) return 'Enter your password';
          if (val.length < 6) return 'Password must be at least 6 characters';
          return null;
        },
      ),
      const SizedBox(height: 16),
      ElevatedButton.icon(
        icon: authState.isLoading
            ? SizedBox(
                height: 17,
                width: 17,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              )
            : Icon(
                _isSignUp
                    ? Icons.person_add_alt_1_rounded
                    : Icons.arrow_forward_rounded,
                size: 18,
              ),
        label: Text(
          authState.isLoading
              ? (_isSignUp ? 'Creating Account...' : 'Signing In...')
              : (_isSignUp ? 'Create Account' : 'Sign In'),
        ),
        onPressed: authState.isLoading ? null : _submitEmail,
      ),
      const SizedBox(height: 6),
      TextButton(
        onPressed: () => setState(() {
          _isSignUp = !_isSignUp;
          _errorMessage = null;
        }),
        child: Text(
          _isSignUp
              ? 'Already have an account? Sign In'
              : "Don't have an account? Create one",
          style: const TextStyle(fontSize: 13),
        ),
      ),
    ];
  }

  List<Widget> _buildPhoneForm(AuthState authState, Color muted) {
    return [
      TextFormField(
        controller: _phoneController,
        enabled: !_otpSent,
        keyboardType: TextInputType.phone,
        textInputAction: _otpSent ? TextInputAction.next : TextInputAction.done,
        autofillHints: const [AutofillHints.telephoneNumber],
        onFieldSubmitted: (_) {
          if (!_otpSent) _submitPhone();
        },
        decoration: const InputDecoration(
          labelText: 'Phone Number',
          hintText: '+92 300 1234567',
          prefixIcon: Icon(Icons.phone_outlined),
        ),
        validator: (val) {
          final cleaned = (val ?? '').trim().replaceAll(RegExp(r'[\s\-()]'), '');
          if (cleaned.isEmpty) return 'Enter your phone number';
          if (!cleaned.startsWith('+') || cleaned.length < 8) {
            return 'Include country code (e.g. +92...)';
          }
          return null;
        },
      ),
      if (_otpSent) ...[
        const SizedBox(height: 12),
        TextFormField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          maxLength: 6,
          onFieldSubmitted: (_) => _submitPhone(),
          decoration: const InputDecoration(
            labelText: '6-Digit Verification Code',
            prefixIcon: Icon(Icons.pin_outlined),
            counterText: '',
          ),
          validator: (val) {
            final code = (val ?? '').trim();
            if (code.length < 6) return 'Enter the 6-digit SMS code';
            return null;
          },
        ),
      ],
      const SizedBox(height: 16),
      ElevatedButton.icon(
        icon: authState.isLoading
            ? SizedBox(
                height: 17,
                width: 17,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              )
            : Icon(
                _otpSent ? Icons.verified_user_outlined : Icons.sms_outlined,
                size: 18,
              ),
        label: Text(
          authState.isLoading
              ? (_otpSent ? 'Verifying...' : 'Sending Code...')
              : (_otpSent ? 'Verify & Sign In' : 'Send Verification Code'),
        ),
        onPressed: authState.isLoading ? null : _submitPhone,
      ),
      if (_otpSent) ...[
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: authState.isLoading
                  ? null
                  : () => setState(() {
                        _otpSent = false;
                        _otpController.clear();
                        _errorMessage = null;
                      }),
              child: const Text('Change Number', style: TextStyle(fontSize: 12)),
            ),
            Text('|', style: TextStyle(color: muted)),
            TextButton(
              onPressed: authState.isLoading
                  ? null
                  : () async {
                      setState(() => _errorMessage = null);
                      try {
                        await ref
                            .read(authProvider.notifier)
                            .sendPhoneOtp(_phoneController.text.trim());
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('New verification code sent.')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          setState(() => _errorMessage = ErrorMessages.friendly(e));
                        }
                      }
                    },
              child: const Text('Resend Code', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ],
    ];
  }
}

class _ModePill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ModePill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final muted = AppTheme.mutedTextOf(context);
    final hairline = AppTheme.hairlineOf(context);

    return Material(
      color: selected ? surface : Colors.transparent,
      shape: StadiumBorder(
        side: selected ? BorderSide(color: hairline) : BorderSide.none,
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: selected ? onSurface : muted),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? onSurface : muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialPillButton extends StatelessWidget {
  final String label;
  final Widget icon;
  final bool disabled;
  final VoidCallback onTap;

  const _SocialPillButton({
    required this.label,
    required this.icon,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hairline = AppTheme.hairlineOf(context);
    final surface = Theme.of(context).colorScheme.surface;

    return Material(
      color: surface,
      shape: StadiumBorder(side: BorderSide(color: hairline)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: disabled ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Crisp vector Google "G" emblem painted natively at any DPI.
class _GoogleMarkPainter extends CustomPainter {
  const _GoogleMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.19;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: (size.width - stroke) / 2,
    );

    void arc(double startDeg, double sweepDeg, Color color) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        rect,
        startDeg * 3.1415926535 / 180,
        sweepDeg * 3.1415926535 / 180,
        false,
        paint,
      );
    }

    arc(-45, 90, const Color(0xFF4285F4));
    arc(45, 95, const Color(0xFF34A853));
    arc(140, 80, const Color(0xFFFBBC05));
    arc(220, 95, const Color(0xFFEA4335));

    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;
    canvas.drawLine(
      Offset(size.width * 0.50, size.height * 0.50),
      Offset(size.width * 0.96, size.height * 0.50),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
