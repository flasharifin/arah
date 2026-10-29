import 'package:arah/core/error/guard.dart';
import 'package:arah/core/error/result.dart';
import 'package:arah/features/networth/data/datasources/net_worth_remote_data_source.dart';
import 'package:arah/features/networth/domain/entities/net_worth.dart';
import 'package:arah/features/networth/domain/repositories/net_worth_repository.dart';

class NetWorthRepositoryImpl implements NetWorthRepository {
  const NetWorthRepositoryImpl(this._remote);
  final NetWorthRemoteDataSource _remote;

  @override
  Future<Result<NetWorth>> getNetWorth() => guard(_remote.fetchNetWorth);
}
