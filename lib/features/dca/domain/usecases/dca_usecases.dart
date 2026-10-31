import 'package:arah/core/error/result.dart';
import 'package:arah/core/usecase/usecase.dart';
import 'package:arah/features/dca/domain/entities/dca.dart';
import 'package:arah/features/dca/domain/repositories/dca_repository.dart';

class GetDcaOverview implements UseCase<DcaOverview, NoParams> {
  const GetDcaOverview(this._repository);
  final DcaRepository _repository;

  @override
  Future<Result<DcaOverview>> call(NoParams params) => _repository.overview();
}

class RecordDcaExecution implements UseCase<void, DcaExecution> {
  const RecordDcaExecution(this._repository);
  final DcaRepository _repository;

  @override
  Future<Result<void>> call(DcaExecution execution) => _repository.recordExecution(execution);
}

class SaveDcaPlan implements UseCase<void, ({DcaPlanDraft draft, String? id})> {
  const SaveDcaPlan(this._repository);
  final DcaRepository _repository;

  @override
  Future<Result<void>> call(({DcaPlanDraft draft, String? id}) params) =>
      _repository.savePlan(params.draft, id: params.id);
}

/// Parameter: id rencana.
class DeleteDcaPlan implements UseCase<void, String> {
  const DeleteDcaPlan(this._repository);
  final DcaRepository _repository;

  @override
  Future<Result<void>> call(String id) => _repository.deletePlan(id);
}
