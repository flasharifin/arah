import 'package:arah/core/state/view_state.dart';
import 'package:arah/features/portfolio/domain/entities/technical.dart';
import 'package:arah/features/portfolio/domain/usecases/get_technical.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Teknikal satu posisi (detail posisi).
class TechnicalCubit extends Cubit<ViewState<TechnicalAnalysis>> {
  TechnicalCubit(this._get, this.positionId) : super(const ViewState());
  final GetTechnical _get;
  final String positionId;

  Future<void> load() async {
    emit(state.loading());
    emit(state.fromResult(await _get(positionId)));
  }
}
