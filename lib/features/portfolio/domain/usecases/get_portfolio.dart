import 'package:arah/core/error/result.dart';
import 'package:arah/core/usecase/usecase.dart';
import 'package:arah/features/portfolio/domain/entities/portfolio.dart';
import 'package:arah/features/portfolio/domain/repositories/portfolio_repository.dart';

class GetPortfolio implements UseCase<Portfolio, NoParams> {
  const GetPortfolio(this._repository);
  final PortfolioRepository _repository;

  @override
  Future<Result<Portfolio>> call(NoParams params) => _repository.getPortfolio();
}
