part of 'portfolio_bloc.dart';

class PortfolioState extends Equatable {
  const PortfolioState({this.data = const ViewState(), this.filter, this.query = ''});

  final ViewState<Portfolio> data;
  final Exchange? filter;
  final String query;

  bool get hasActiveFilter => filter != null || query.isNotEmpty;

  List<Position> get visiblePositions {
    final q = query.trim().toUpperCase();
    return (data.data?.positions ?? const <Position>[])
        .where((p) => filter == null || p.exchange == filter)
        .where((p) => q.isEmpty || p.symbol.contains(q))
        .toList();
  }

  Position? positionById(String id) => data.data?.positions.where((p) => p.id == id).firstOrNull;

  /// [filter] berupa fungsi agar bisa di-set ke `null` (Semua).
  PortfolioState copyWith({ViewState<Portfolio>? data, Exchange? Function()? filter, String? query}) => PortfolioState(
    data: data ?? this.data,
    filter: filter != null ? filter() : this.filter,
    query: query ?? this.query,
  );

  @override
  List<Object?> get props => [data, filter, query];
}
