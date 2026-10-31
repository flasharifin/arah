import 'package:arah/core/state/view_state.dart';
import 'package:arah/core/usecase/usecase.dart';
import 'package:arah/features/portfolio/domain/entities/performance.dart';
import 'package:arah/features/portfolio/domain/usecases/performance_usecases.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Tab Kinerja: PnL harian 1 tahun, periode difilter di layar.
class PerformanceCubit extends Cubit<ViewState<List<DailyPerformance>>> {
  PerformanceCubit(this._get) : super(const ViewState());
  final GetDailyPerformance _get;

  Future<void> load() async {
    emit(state.loading());
    emit(state.fromResult(await _get(const NoParams())));
  }
}

/// Tab Riwayat: transaksi jual.
class SalesCubit extends Cubit<ViewState<List<SaleRecord>>> {
  SalesCubit(this._get) : super(const ViewState());
  final GetSales _get;

  Future<void> load() async {
    emit(state.loading());
    emit(state.fromResult(await _get(const NoParams())));
  }
}
