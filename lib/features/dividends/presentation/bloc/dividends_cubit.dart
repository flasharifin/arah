import 'package:arah/core/state/view_state.dart';
import 'package:arah/core/usecase/usecase.dart';
import 'package:arah/features/dividends/domain/entities/dividend.dart';
import 'package:arah/features/dividends/domain/usecases/get_dividends.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DividendsCubit extends Cubit<ViewState<List<Dividend>>> {
  DividendsCubit(this._get) : super(const ViewState());
  final GetDividends _get;

  Future<void> load() async {
    emit(state.loading());
    emit(state.fromResult(await _get(const NoParams())));
  }
}
