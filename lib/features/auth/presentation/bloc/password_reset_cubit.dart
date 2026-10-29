import 'package:arah/core/error/failure.dart';
import 'package:arah/features/auth/domain/usecases/auth_usecases.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// email → kode dikirim → isi kode & password baru → selesai.
enum PasswordResetStep { email, code, done }

class PasswordResetState extends Equatable {
  const PasswordResetState({
    this.step = PasswordResetStep.email,
    this.email = '',
    this.isSubmitting = false,
    this.failure,
  });

  final PasswordResetStep step;
  final String email;
  final bool isSubmitting;
  final Failure? failure;

  @override
  List<Object?> get props => [step, email, isSubmitting, failure];
}

class PasswordResetCubit extends Cubit<PasswordResetState> {
  PasswordResetCubit({required RequestPasswordReset requestReset, required ResetPassword resetPassword})
    : _requestReset = requestReset,
      _resetPassword = resetPassword,
      super(const PasswordResetState());

  final RequestPasswordReset _requestReset;
  final ResetPassword _resetPassword;

  /// Dipakai juga untuk "kirim ulang kode" dari langkah kode.
  Future<void> requestCode(String email) async {
    if (state.isSubmitting) return;
    emit(PasswordResetState(step: state.step, email: email, isSubmitting: true));
    final result = await _requestReset(email);
    emit(
      result.fold(
        (failure) => PasswordResetState(step: state.step, email: email, failure: failure),
        (_) => PasswordResetState(step: PasswordResetStep.code, email: email),
      ),
    );
  }

  Future<void> reset({required String code, required String newPassword}) async {
    if (state.isSubmitting) return;
    emit(PasswordResetState(step: state.step, email: state.email, isSubmitting: true));
    final result = await _resetPassword(
      ResetPasswordParams(email: state.email, code: code, newPassword: newPassword),
    );
    emit(
      result.fold(
        (failure) => PasswordResetState(step: state.step, email: state.email, failure: failure),
        (_) => PasswordResetState(step: PasswordResetStep.done, email: state.email),
      ),
    );
  }

  /// Kembali ke langkah email (mis. salah ketik email).
  void changeEmail() => emit(const PasswordResetState());
}
