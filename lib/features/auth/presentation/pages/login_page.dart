import 'package:arah/core/security/biometric_lock.dart';
import 'package:arah/core/theme/app_colors.dart';
import 'package:arah/core/theme/app_spacing.dart';
import 'package:arah/core/widgets/widgets.dart';
import 'package:arah/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// S01 — Masuk. Daftar akun belum disambungkan ke backend mobile.
/// Tombol sidik jari (Android) / Face ID (iOS) selalu tampil; aktif jika sesi tersimpan terkunci.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthBloc>().state;
    if (auth.status == AuthStatus.locked) _email.text = auth.user?.email ?? '';
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthBloc>().add(AuthLoginRequested(email: _email.text, password: _password.text));
  }

  void _biometricLogin(AuthState state) {
    if (state.status == AuthStatus.locked) {
      context.read<AuthBloc>().add(const AuthUnlockRequested());
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Masuk dengan ${BiometricLock.name} belum diaktifkan. Masuk dengan password, '
            'lalu aktifkan di Lainnya → Kunci dengan ${BiometricLock.name}.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
          child: PageBody(
            child: Form(
              key: _formKey,
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Image(
                      image: AssetImage('assets/images/arah-logo.png'),
                      height: 120,
                      semanticLabel: 'Arah',
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    Text('Kenali asetmu.\nTentukan langkahmu.', style: text.headlineSmall),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Catat investasi, pantau kekayaan, dan tanyakan datamu ke AI.',
                      style: text.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    AppTextField(
                      label: 'Email',
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      validator: (v) => (v ?? '').contains('@') ? null : 'Masukkan email yang valid',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    PasswordField(
                      controller: _password,
                      validator: (v) => (v ?? '').isEmpty ? 'Password wajib diisi' : null,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => context.go('/forgot-password'),
                        child: const Text('Lupa password?'),
                      ),
                    ),
                    BlocBuilder<AuthBloc, AuthState>(
                      builder: (context, state) => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (state.failure != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.md),
                              child: Text(
                                state.failure!.message,
                                style: text.bodySmall?.copyWith(color: AppColors.negative),
                              ),
                            ),
                          Row(
                            children: [
                              Expanded(
                                child: PrimaryButton(
                                  label: 'Masuk',
                                  busy: state.isSubmitting,
                                  onPressed: _submit,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              OutlinedButton(
                                onPressed: state.isSubmitting ? null : () => _biometricLogin(state),
                                // Tema memberi lebar minimum tak hingga; tombol ikon ini persegi setinggi tombol Masuk.
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.square(AppSpacing.primaryButtonHeight),
                                  padding: EdgeInsets.zero,
                                ),
                                child: Icon(
                                  BiometricLock.icon,
                                  size: 28,
                                  semanticLabel: 'Masuk dengan ${BiometricLock.name}',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // Daftar belum aktif sampai endpoint registrasi mobile tersedia.
                    const OutlinedButton(onPressed: null, child: Text('Buat akun')),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
