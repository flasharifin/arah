import 'package:arah/core/error/result.dart';
import 'package:arah/features/portfolio/domain/entities/portfolio.dart';
import 'package:arah/features/portfolio/domain/entities/purchase.dart';

abstract interface class PortfolioRepository {
  Future<Result<Portfolio>> getPortfolio();
  Future<Result<void>> recordPurchase(PositionPurchase purchase);
}
