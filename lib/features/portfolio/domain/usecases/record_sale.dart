import 'package:arah/core/error/result.dart';
import 'package:arah/core/usecase/usecase.dart';
import 'package:arah/features/portfolio/domain/entities/sale.dart';
import 'package:arah/features/portfolio/domain/repositories/portfolio_repository.dart';

class RecordSale implements UseCase<void, PositionSale> {
  const RecordSale(this._repository);
  final PortfolioRepository _repository;

  @override
  Future<Result<void>> call(PositionSale sale) => _repository.recordSale(sale);
}
