import 'package:arah/core/error/result.dart';
import 'package:arah/features/networth/domain/entities/net_worth.dart';

abstract interface class NetWorthRepository {
  Future<Result<NetWorth>> getNetWorth();
  Future<Result<void>> saveEntry(ManualEntry entry, {String? id});
  Future<Result<void>> removeEntry(WealthKind kind, String id);
  Future<Result<void>> createSnapshot();
  Future<Result<void>> removeSnapshot(String id);
}
