import 'package:arah/core/error/result.dart';
import 'package:arah/core/state/view_state.dart';
import 'package:arah/core/usecase/usecase.dart';
import 'package:arah/features/dca/domain/entities/dca.dart';
import 'package:arah/features/dca/domain/usecases/dca_usecases.dart';
import 'package:arah/features/portfolio/domain/usecases/get_portfolio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DcaCubit extends Cubit<ViewState<DcaOverview>> {
  DcaCubit({
    required GetDcaOverview get,
    required RecordDcaExecution record,
    required SaveDcaPlan savePlan,
    required DeleteDcaPlan deletePlan,
    required GetPortfolio getPortfolio,
  }) : _get = get,
       _record = record,
       _savePlan = savePlan,
       _deletePlan = deletePlan,
       _getPortfolio = getPortfolio,
       super(const ViewState());

  final GetDcaOverview _get;
  final RecordDcaExecution _record;
  final SaveDcaPlan _savePlan;
  final DeleteDcaPlan _deletePlan;
  final GetPortfolio _getPortfolio;

  /// Rencana & riwayat wajib; posisi (pilihan & mata uang) opsional — gagal dimuat tidak menggagalkan layar.
  Future<void> load() async {
    emit(state.loading());
    final (overview, portfolio) = await (_get(const NoParams()), _getPortfolio(const NoParams())).wait;
    final positions = portfolio.fold((_) => null, (p) => p.positions);
    final withPositions = positions == null
        ? overview
        : overview.fold<Result<DcaOverview>>(Error.new, (o) => Success(o.withPositions(positions)));
    emit(state.fromResult(withPositions));
  }

  Future<Result<void>> record(DcaExecution execution) => _thenReload(_record(execution));
  Future<Result<void>> savePlan(DcaPlanDraft draft, {String? id}) => _thenReload(_savePlan((draft: draft, id: id)));
  Future<Result<void>> deletePlan(String id) => _thenReload(_deletePlan(id));

  Future<Result<void>> _thenReload(Future<Result<void>> action) async {
    final result = await action;
    if (result is Success<void>) await load();
    return result;
  }
}
