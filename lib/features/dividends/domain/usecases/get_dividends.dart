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

class SaveDividend implements UseCase<void, ({DividendDraft draft, String? id})> {
  const SaveDividend(this._repository);
  final DividendRepository _repository;

  @override
  Future<Result<void>> call(({DividendDraft draft, String? id}) params) =>
      _repository.save(params.draft, id: params.id);
}

/// Parameter: id dividen.
class RemoveDividend implements UseCase<void, String> {
  const RemoveDividend(this._repository);
  final DividendRepository _repository;

  @override
  Future<Result<void>> call(String id) => _repository.remove(id);
}
