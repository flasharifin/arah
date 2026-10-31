import 'package:arah/core/error/result.dart';
import 'package:arah/features/dividends/domain/entities/dividend.dart';

abstract interface class DividendRepository {
  Future<Result<List<Dividend>>> list();

  /// [id] null = tambah baru.
  Future<Result<void>> save(DividendDraft draft, {String? id});
  Future<Result<void>> remove(String id);
}
