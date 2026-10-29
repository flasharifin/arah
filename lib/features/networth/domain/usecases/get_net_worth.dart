import 'package:arah/core/error/result.dart';
import 'package:arah/core/usecase/usecase.dart';
import 'package:arah/features/networth/domain/entities/net_worth.dart';
import 'package:arah/features/networth/domain/repositories/net_worth_repository.dart';

class GetNetWorth implements UseCase<NetWorth, NoParams> {
  const GetNetWorth(this._repository);
  final NetWorthRepository _repository;

  @override
  Future<Result<NetWorth>> call(NoParams params) => _repository.getNetWorth();
}
