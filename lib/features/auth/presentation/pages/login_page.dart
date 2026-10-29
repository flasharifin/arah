import 'package:arah/core/theme/app_colors.dart';
import 'package:arah/core/theme/app_spacing.dart';
import 'package:arah/core/widgets/widgets.dart';
import 'package:arah/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// S01 — Masuk. Daftar akun belum disambungkan ke backend mobile.
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
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthBloc>().add(AuthLoginRequested(email: _email.text, password: _password.text));
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
                    const SizedBox(height: AppSpacing.lg),
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
                          PrimaryButton(label: 'Masuk', busy: state.isSubmitting, onPressed: _submit),
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
