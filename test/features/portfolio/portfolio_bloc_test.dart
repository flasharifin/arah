import 'package:arah/core/error/result.dart';
import 'package:arah/core/state/view_state.dart';
import 'package:arah/features/portfolio/data/datasources/portfolio_remote_data_source.dart';
import 'package:arah/features/portfolio/domain/entities/portfolio.dart';
import 'package:arah/features/portfolio/domain/entities/position.dart';
import 'package:arah/features/portfolio/domain/entities/purchase.dart';
import 'package:arah/features/portfolio/domain/repositories/portfolio_repository.dart';
import 'package:arah/features/portfolio/domain/usecases/get_portfolio.dart';
import 'package:arah/features/portfolio/presentation/bloc/portfolio_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixtureRepository implements PortfolioRepository {
  @override
  Future<Result<Portfolio>> getPortfolio() async =>
      Success(await PortfolioFixtureDataSource().fetchPortfolio());

  @override
  Future<Result<void>> recordPurchase(PositionPurchase purchase) => throw UnimplementedError();
}

void main() {
  PortfolioBloc build() => PortfolioBloc(GetPortfolio(_FixtureRepository()));

  blocTest<PortfolioBloc, PortfolioState>(
    'memuat lalu sukses',
    build: build,
    act: (b) => b.add(const PortfolioRequested()),
    wait: const Duration(seconds: 1),
    expect: () => [
      isA<PortfolioState>().having((s) => s.data.status, 'status', ViewStatus.loading),
      isA<PortfolioState>().having((s) => s.data.status, 'status', ViewStatus.success),
    ],
  );

  blocTest<PortfolioBloc, PortfolioState>(
    'filter bursa dan pencarian ticker',
    build: build,
    act: (b) async {
      b.add(const PortfolioRequested());
      await Future<void>.delayed(const Duration(seconds: 1));
      b
        ..add(const PortfolioFilterChanged(Exchange.idx))
        ..add(const PortfolioQueryChanged('tl'));
    },
    wait: const Duration(milliseconds: 100),
    verify: (b) => expect(b.state.visiblePositions.map((p) => p.symbol), ['TLKM']),
  );
}
