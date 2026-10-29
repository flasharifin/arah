import 'package:arah/core/error/result.dart';
import 'package:arah/features/dividends/domain/entities/dividend.dart';

abstract interface class DividendRepository {
  Future<Result<List<Dividend>>> list();
}
