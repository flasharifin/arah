import 'package:arah/core/error/result.dart';
import 'package:arah/core/usecase/usecase.dart';
import 'package:arah/features/portfolio/domain/entities/purchase.dart';
import 'package:arah/features/portfolio/domain/repositories/portfolio_repository.dart';

class RecordPurchase implements UseCase<void, PositionPurchase> {
  const RecordPurchase(this._repository);
  final PortfolioRepository _repository;

  @override
  Future<Result<void>> call(PositionPurchase purchase) => _repository.recordPurchase(purchase);
}
