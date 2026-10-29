import 'package:arah/core/state/view_state.dart';
import 'package:arah/core/usecase/usecase.dart';
import 'package:arah/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:arah/features/dashboard/domain/usecases/get_dashboard_summary.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DashboardCubit extends Cubit<ViewState<DashboardSummary>> {
  DashboardCubit(this._getSummary) : super(const ViewState());

  final GetDashboardSummary _getSummary;

  Future<void> load() async {
    emit(state.loading());
    emit(state.fromResult(await _getSummary(const NoParams())));
  }
}
