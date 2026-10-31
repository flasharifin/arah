import 'package:arah/core/state/view_state.dart';
import 'package:arah/core/usecase/usecase.dart';
import 'package:arah/features/letter/domain/entities/investor_letter.dart';
import 'package:arah/features/letter/domain/usecases/get_investor_letter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LetterCubit extends Cubit<ViewState<InvestorLetter>> {
  LetterCubit(this._get) : super(const ViewState());
  final GetInvestorLetter _get;

  Future<void> load() async {
    emit(state.loading());
    emit(state.fromResult(await _get(const NoParams())));
  }
}
