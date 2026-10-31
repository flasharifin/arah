import 'package:arah/core/state/view_state.dart';
import 'package:arah/core/usecase/usecase.dart';
import 'package:arah/features/calculator/domain/entities/insights.dart';
import 'package:arah/features/calculator/domain/usecases/insights_usecases.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class InvisibleCostCubit extends Cubit<ViewState<List<InvisibleCost>>> {
  InvisibleCostCubit(this._get) : super(const ViewState());
  final GetInvisibleCost _get;

  Future<void> load() async {
    emit(state.loading());
    emit(state.fromResult(await _get(const NoParams())));
  }
}

class WealthTimelineCubit extends Cubit<ViewState<WealthTimeline>> {
  WealthTimelineCubit(this._get) : super(const ViewState());
  final GetWealthTimeline _get;

  Future<void> load() async {
    emit(state.loading());
    emit(state.fromResult(await _get(const NoParams())));
  }
}
