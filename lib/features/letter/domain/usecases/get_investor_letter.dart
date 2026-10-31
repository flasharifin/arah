import 'package:arah/core/error/result.dart';
import 'package:arah/core/usecase/usecase.dart';
import 'package:arah/features/letter/domain/entities/investor_letter.dart';
import 'package:arah/features/letter/domain/repositories/letter_repository.dart';

class GetInvestorLetter implements UseCase<InvestorLetter, NoParams> {
  const GetInvestorLetter(this._repository);
  final LetterRepository _repository;

  @override
  Future<Result<InvestorLetter>> call(NoParams params) => _repository.get();
}
