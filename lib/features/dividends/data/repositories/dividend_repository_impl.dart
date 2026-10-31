import 'package:arah/core/error/guard.dart';
import 'package:arah/core/error/result.dart';
import 'package:arah/features/dividends/data/datasources/dividend_remote_data_source.dart';
import 'package:arah/features/dividends/domain/entities/dividend.dart';
import 'package:arah/features/dividends/domain/repositories/dividend_repository.dart';

class DividendRepositoryImpl implements DividendRepository {
  const DividendRepositoryImpl(this._remote);
  final DividendRemoteDataSource _remote;

  @override
  Future<Result<List<Dividend>>> list() => guard(_remote.list);

  @override
  Future<Result<void>> save(DividendDraft draft, {String? id}) => guard(() => _remote.save(draft, id: id));

  @override
  Future<Result<void>> remove(String id) => guard(() => _remote.remove(id));
}
