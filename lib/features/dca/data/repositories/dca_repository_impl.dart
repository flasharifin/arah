import 'package:arah/core/error/guard.dart';
import 'package:arah/core/error/result.dart';
import 'package:arah/features/dca/data/datasources/dca_remote_data_source.dart';
import 'package:arah/features/dca/domain/entities/dca.dart';
import 'package:arah/features/dca/domain/repositories/dca_repository.dart';

class DcaRepositoryImpl implements DcaRepository {
  const DcaRepositoryImpl(this._remote);
  final DcaRemoteDataSource _remote;

  @override
  Future<Result<DcaOverview>> overview() => guard(_remote.overview);

  @override
  Future<Result<void>> recordExecution(DcaExecution execution) => guard(() => _remote.recordExecution(execution));

  @override
  Future<Result<void>> savePlan(DcaPlanDraft draft, {String? id}) => guard(() => _remote.savePlan(draft, id: id));

  @override
  Future<Result<void>> deletePlan(String id) => guard(() => _remote.deletePlan(id));
}
