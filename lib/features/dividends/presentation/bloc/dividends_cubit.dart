import 'package:arah/core/error/result.dart';
import 'package:arah/core/state/view_state.dart';
import 'package:arah/core/usecase/usecase.dart';
import 'package:arah/features/dividends/domain/entities/dividend.dart';
import 'package:arah/features/dividends/domain/usecases/get_dividends.dart';
import 'package:arah/features/portfolio/domain/entities/position.dart';
import 'package:arah/features/portfolio/domain/usecases/get_portfolio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DividendsCubit extends Cubit<ViewState<List<Dividend>>> {
  DividendsCubit({
    required GetDividends get,
    required SaveDividend save,
    required RemoveDividend remove,
    required GetPortfolio getPortfolio,
  }) : _get = get,
       _save = save,
       _remove = remove,
       _getPortfolio = getPortfolio,
       super(const ViewState());

  final GetDividends _get;
  final SaveDividend _save;
  final RemoveDividend _remove;
  final GetPortfolio _getPortfolio;

  /// Pilihan posisi untuk form tambah; dimuat bersama daftar, kosong bila gagal.
  List<Position> positions = const [];

  Future<void> load() async {
    emit(state.loading());
    final (dividends, portfolio) = await (_get(const NoParams()), _getPortfolio(const NoParams())).wait;
    positions = portfolio.fold((_) => const [], (p) => p.positions);
    emit(state.fromResult(dividends));
  }

  Future<Result<void>> save(DividendDraft draft, {String? id}) => _thenReload(_save((draft: draft, id: id)));
  Future<Result<void>> remove(String id) => _thenReload(_remove(id));

  Future<Result<void>> _thenReload(Future<Result<void>> action) async {
    final result = await action;
    if (result is Success<void>) await load();
    return result;
  }
}
