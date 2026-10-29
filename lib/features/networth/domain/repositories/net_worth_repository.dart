import 'package:arah/core/error/result.dart';
import 'package:arah/features/networth/domain/entities/net_worth.dart';

abstract interface class NetWorthRepository {
  Future<Result<NetWorth>> getNetWorth();
}
