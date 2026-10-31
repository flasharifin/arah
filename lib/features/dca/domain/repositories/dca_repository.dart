import 'package:arah/core/error/result.dart';
import 'package:arah/features/dca/domain/entities/dca.dart';

abstract interface class DcaRepository {
  Future<Result<DcaOverview>> overview();
  Future<Result<void>> recordExecution(DcaExecution execution);

  /// [id] null = rencana baru.
  Future<Result<void>> savePlan(DcaPlanDraft draft, {String? id});
  Future<Result<void>> deletePlan(String id);
}
