import 'package:arah/core/theme/app_colors.dart';
import 'package:arah/core/theme/app_spacing.dart';
import 'package:arah/core/widgets/widgets.dart';
import 'package:arah/features/auth/presentation/bloc/password_reset_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Lupa password: kode 6 digit dikirim ke email (`/api/auth/password/forgot` & `/reset`).
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    for (final c in [_email, _code, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit(PasswordResetState state) {
    if (!_formKey.currentState!.validate()) return;
    final cubit = context.read<PasswordResetCubit>();
    if (state.step == PasswordResetStep.email) {
      cubit.requestCode(_email.text);
    } else {
      cubit.reset(code: _code.text, newPassword: _password.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Lupa password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
          child: PageBody(
            child: BlocBuilder<PasswordResetCubit, PasswordResetState>(
              builder: (context, state) {
                if (state.step == PasswordResetStep.done) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Password sudah diganti', style: text.titleLarge),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Masuk dengan password barumu. Sesi di perangkat lain sudah dikeluarkan.',
                        style: text.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      PrimaryButton(label: 'Masuk', onPressed: () => context.go('/login')),
                    ],
                  );
                }
                final askingCode = state.step == PasswordResetStep.code;
                return Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        askingCode
                            ? 'Kalau ${state.email} terdaftar, kode 6 digit sudah dikirim ke email itu. Kode berlaku 15 menit.'
                            : 'Masukkan email akunmu. Kami kirim kode untuk membuat password baru.',
                        style: text.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      if (!askingCode)
                        AppTextField(
                          label: 'Email',
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          validator: (v) => (v ?? '').contains('@') ? null : 'Masukkan email yang valid',
                        )
                      else ...[
                        AppTextField(
                          label: 'Kode dari email',
                          controller: _code,
                          keyboardType: TextInputType.number,
                          autofillHints: const [AutofillHints.oneTimeCode],
                          validator: (v) => RegExp(r'^\d{6}$').hasMatch((v ?? '').trim())
                              ? null
                              : 'Kode terdiri dari 6 angka',
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        PasswordField(
                          controller: _password,
                          label: 'Password baru',
                          validator: (v) => (v ?? '').length < 6 ? 'Password minimal 6 karakter' : null,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        PasswordField(
                          controller: _confirm,
                          label: 'Ulangi password baru',
                          validator: (v) => v == _password.text ? null : 'Password tidak sama',
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      if (state.failure != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: Text(
                            state.failure!.message,
                            style: text.bodySmall?.copyWith(color: AppColors.negative),
                          ),
                        ),
                      PrimaryButton(
                        label: askingCode ? 'Simpan password baru' : 'Kirim kode',
                        busy: state.isSubmitting,
                        onPressed: () => _submit(state),
                      ),
                      if (askingCode) ...[
                        const SizedBox(height: AppSpacing.sm),
                        TextButton(
                          onPressed: state.isSubmitting
                              ? null
                              : () => context.read<PasswordResetCubit>().requestCode(state.email),
                          child: const Text('Kirim ulang kode'),
                        ),
                        TextButton(
                          onPressed: state.isSubmitting
                              ? null
                              : context.read<PasswordResetCubit>().changeEmail,
                          child: const Text('Ganti email'),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
