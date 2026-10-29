import 'package:arah/core/error/result.dart';
import 'package:arah/features/journal/domain/entities/journal.dart';

abstract interface class JournalRepository {
  Future<Result<JournalData>> load();
  Future<Result<void>> saveNote(String day, String note);
}
