import 'package:flutter_bloc/flutter_bloc.dart';

/// Mode privasi global: `true` menyembunyikan semua nominal tanpa mengubah data.
class PrivacyCubit extends Cubit<bool> {
  PrivacyCubit() : super(false);

  void toggle() => emit(!state);
}
