part of 'portfolio_bloc.dart';

sealed class PortfolioEvent extends Equatable {
  const PortfolioEvent();

  @override
  List<Object?> get props => [];
}

/// Muat pertama kali atau refresh; data lama tetap tampil selama memuat.
final class PortfolioRequested extends PortfolioEvent {
  const PortfolioRequested();
}

final class PortfolioFilterChanged extends PortfolioEvent {
  const PortfolioFilterChanged(this.exchange);

  /// `null` = Semua.
  final Exchange? exchange;

  @override
  List<Object?> get props => [exchange];
}

final class PortfolioQueryChanged extends PortfolioEvent {
  const PortfolioQueryChanged(this.query);
  final String query;

  @override
  List<Object?> get props => [query];
}
