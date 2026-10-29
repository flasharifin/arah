import 'package:arah/core/error/result.dart';
import 'package:arah/core/usecase/usecase.dart';
import 'package:arah/features/dividends/domain/entities/dividend.dart';
import 'package:arah/features/dividends/domain/repositories/dividend_repository.dart';

class GetDividends implements UseCase<List<Dividend>, NoParams> {
  const GetDividends(this._repository);
  final DividendRepository _repository;

  @override
  Future<Result<List<Dividend>>> call(NoParams params) => _repository.list();
}
