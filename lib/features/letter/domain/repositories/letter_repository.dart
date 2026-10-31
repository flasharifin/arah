import 'package:arah/core/error/result.dart';
import 'package:arah/features/letter/domain/entities/investor_letter.dart';

abstract interface class LetterRepository {
  Future<Result<InvestorLetter>> get();
}
