import 'package:arah/core/state/view_state.dart';
import 'package:arah/core/usecase/usecase.dart';
import 'package:arah/features/portfolio/domain/entities/portfolio.dart';
import 'package:arah/features/portfolio/domain/entities/position.dart';
import 'package:arah/features/portfolio/domain/usecases/get_portfolio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'portfolio_event.dart';
part 'portfolio_state.dart';

class PortfolioBloc extends Bloc<PortfolioEvent, PortfolioState> {
  PortfolioBloc(this._getPortfolio) : super(const PortfolioState()) {
    on<PortfolioRequested>(_onRequested);
    on<PortfolioFilterChanged>((e, emit) => emit(state.copyWith(filter: () => e.exchange)));
    on<PortfolioQueryChanged>((e, emit) => emit(state.copyWith(query: e.query)));
  }

  final GetPortfolio _getPortfolio;

  Future<void> _onRequested(PortfolioRequested event, Emitter<PortfolioState> emit) async {
    emit(state.copyWith(data: state.data.loading()));
    final result = await _getPortfolio(const NoParams());
    emit(state.copyWith(data: state.data.fromResult(result)));
  }
}
