import 'package:arah/core/error/result.dart';
import 'package:arah/core/state/view_state.dart';
import 'package:arah/core/usecase/usecase.dart';
import 'package:arah/features/journal/domain/entities/journal.dart';
import 'package:arah/features/journal/domain/usecases/journal_usecases.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class JournalCubit extends Cubit<ViewState<JournalData>> {
  JournalCubit({required GetJournal get, required SaveJournalNote save})
    : _get = get,
      _save = save,
      super(const ViewState());

  final GetJournal _get;
  final SaveJournalNote _save;

  Future<void> load() async {
    emit(state.loading());
    emit(state.fromResult(await _get(const NoParams())));
  }

  Future<Result<void>> save(String day, String note) async {
    final result = await _save((day: day, note: note));
    final data = state.data;
    if (result is Success<void> && data != null) {
      emit(ViewState(status: state.status, data: data.withNote(day, note.trim())));
    }
    return result;
  }
}
