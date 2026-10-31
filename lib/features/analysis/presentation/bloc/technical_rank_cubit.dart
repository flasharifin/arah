import 'package:arah/core/state/view_state.dart';
import 'package:arah/core/usecase/usecase.dart';
import 'package:arah/features/analysis/domain/entities/technical_rank.dart';
import 'package:arah/features/analysis/domain/usecases/get_technical_ranking.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TechnicalRankCubit extends Cubit<ViewState<TechnicalRanking>> {
  TechnicalRankCubit(this._get) : super(const ViewState());
  final GetTechnicalRanking _get;

  Future<void> load() async {
    emit(state.loading());
    emit(state.fromResult(await _get(const NoParams())));
  }
}
