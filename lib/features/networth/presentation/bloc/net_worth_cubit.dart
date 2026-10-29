import 'package:arah/core/state/view_state.dart';
import 'package:arah/core/usecase/usecase.dart';
import 'package:arah/features/networth/domain/entities/net_worth.dart';
import 'package:arah/features/networth/domain/usecases/get_net_worth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class NetWorthCubit extends Cubit<ViewState<NetWorth>> {
  NetWorthCubit(this._getNetWorth) : super(const ViewState());

  final GetNetWorth _getNetWorth;

  Future<void> load() async {
    emit(state.loading());
    emit(state.fromResult(await _getNetWorth(const NoParams())));
  }
}
