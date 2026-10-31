import 'package:arah/core/error/result.dart';
import 'package:arah/core/state/view_state.dart';
import 'package:arah/core/usecase/usecase.dart';
import 'package:arah/features/settings/domain/entities/account_settings.dart';
import 'package:arah/features/settings/domain/usecases/settings_usecases.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SettingsCubit extends Cubit<ViewState<AccountSettings>> {
  SettingsCubit({required GetSettings get, required SaveSettings save})
    : _get = get,
      _save = save,
      super(const ViewState());

  final GetSettings _get;
  final SaveSettings _save;

  Future<void> load() async {
    emit(state.loading());
    emit(state.fromResult(await _get(const NoParams())));
  }

  Future<Result<AccountSettings>> save({required String? telegramChatId, required double drawdownThreshold}) async {
    final result = await _save((telegramChatId: telegramChatId, drawdownThreshold: drawdownThreshold));
    if (result is Success<AccountSettings>) emit(state.fromResult(result));
    return result;
  }
}
