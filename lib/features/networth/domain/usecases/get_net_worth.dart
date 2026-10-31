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

class SaveWealthEntry implements UseCase<void, ({ManualEntry entry, String? id})> {
  const SaveWealthEntry(this._repository);
  final NetWorthRepository _repository;

  @override
  Future<Result<void>> call(({ManualEntry entry, String? id}) params) =>
      _repository.saveEntry(params.entry, id: params.id);
}

class RemoveWealthEntry implements UseCase<void, ({WealthKind kind, String id})> {
  const RemoveWealthEntry(this._repository);
  final NetWorthRepository _repository;

  @override
  Future<Result<void>> call(({WealthKind kind, String id}) params) => _repository.removeEntry(params.kind, params.id);
}

class CreateNetWorthSnapshot implements UseCase<void, NoParams> {
  const CreateNetWorthSnapshot(this._repository);
  final NetWorthRepository _repository;

  @override
  Future<Result<void>> call(NoParams params) => _repository.createSnapshot();
}

/// Parameter: id snapshot.
class RemoveNetWorthSnapshot implements UseCase<void, String> {
  const RemoveNetWorthSnapshot(this._repository);
  final NetWorthRepository _repository;

  @override
  Future<Result<void>> call(String id) => _repository.removeSnapshot(id);
}
