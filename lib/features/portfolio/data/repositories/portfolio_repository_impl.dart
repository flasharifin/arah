import 'package:arah/core/error/guard.dart';
import 'package:arah/core/error/result.dart';
import 'package:arah/features/portfolio/data/datasources/portfolio_remote_data_source.dart';
import 'package:arah/features/portfolio/domain/entities/portfolio.dart';
import 'package:arah/features/portfolio/domain/entities/purchase.dart';
import 'package:arah/features/portfolio/domain/repositories/portfolio_repository.dart';

class PortfolioRepositoryImpl implements PortfolioRepository {
  const PortfolioRepositoryImpl(this._remote);
  final PortfolioRemoteDataSource _remote;

  @override
  Future<Result<Portfolio>> getPortfolio() => guard(_remote.fetchPortfolio);

  @override
  Future<Result<void>> recordPurchase(PositionPurchase purchase) =>
      guard(() => _remote.recordPurchase(purchase));
}
