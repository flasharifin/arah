import 'package:arah/core/state/view_state.dart';
import 'package:arah/core/usecase/usecase.dart';
import 'package:arah/features/analysis/domain/entities/risk_analysis.dart';
import 'package:arah/features/analysis/domain/usecases/get_risk_analysis.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AnalysisCubit extends Cubit<ViewState<RiskAnalysis>> {
  AnalysisCubit(this._get) : super(const ViewState());
  final GetRiskAnalysis _get;

  Future<void> load() async {
    emit(state.loading());
    emit(state.fromResult(await _get(const NoParams())));
  }
}
