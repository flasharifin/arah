import 'package:arah/core/error/guard.dart';
import 'package:arah/core/error/result.dart';
import 'package:arah/features/portfolio/data/datasources/technical_remote_data_source.dart';
import 'package:arah/features/portfolio/domain/entities/technical.dart';
import 'package:arah/features/portfolio/domain/repositories/technical_repository.dart';

class TechnicalRepositoryImpl implements TechnicalRepository {
  const TechnicalRepositoryImpl(this._remote);
  final TechnicalRemoteDataSource _remote;

  @override
  Future<Result<TechnicalAnalysis>> get(String positionId) => guard(() => _remote.fetch(positionId));
}
