import 'package:arah/core/error/result.dart';
import 'package:arah/features/portfolio/domain/entities/portfolio.dart';

abstract interface class PortfolioRepository {
  Future<Result<Portfolio>> getPortfolio();
}
