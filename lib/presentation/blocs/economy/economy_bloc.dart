import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mirror_logic/data/repositories/economy_repository.dart';

sealed class EconomyEvent extends Equatable {
  const EconomyEvent();
  @override
  List<Object?> get props => [];
}

class EconomyStarted extends EconomyEvent {
  const EconomyStarted();
}

class EconomyCoinsChanged extends EconomyEvent {
  const EconomyCoinsChanged(this.coins);
  final int coins;
  @override
  List<Object?> get props => [coins];
}

class EconomySpendRequested extends EconomyEvent {
  const EconomySpendRequested(this.amount);
  final int amount;
  @override
  List<Object?> get props => [amount];
}

class EconomyState extends Equatable {
  const EconomyState({required this.coins, this.lastSpendFailed = false});
  final int coins;
  final bool lastSpendFailed;

  EconomyState copyWith({int? coins, bool? lastSpendFailed}) {
    return EconomyState(
      coins: coins ?? this.coins,
      lastSpendFailed: lastSpendFailed ?? this.lastSpendFailed,
    );
  }

  @override
  List<Object?> get props => [coins, lastSpendFailed];
}

class EconomyBloc extends Bloc<EconomyEvent, EconomyState> {
  EconomyBloc({required EconomyRepository economyRepository})
      : _economyRepository = economyRepository,
        super(EconomyState(coins: economyRepository.getCoins())) {
    on<EconomyStarted>(_onStarted);
    on<EconomyCoinsChanged>(_onChanged);
    on<EconomySpendRequested>(_onSpend);
  }

  final EconomyRepository _economyRepository;

  void _onStarted(EconomyStarted event, Emitter<EconomyState> emit) {
    emit(EconomyState(coins: _economyRepository.getCoins()));
  }

  void _onChanged(EconomyCoinsChanged event, Emitter<EconomyState> emit) {
    emit(state.copyWith(coins: event.coins, lastSpendFailed: false));
  }

  Future<void> _onSpend(
    EconomySpendRequested event,
    Emitter<EconomyState> emit,
  ) async {
    final result = await _economyRepository.spendCoins(event.amount);
    if (result == null) {
      emit(state.copyWith(lastSpendFailed: true));
      return;
    }
    emit(EconomyState(coins: result.coins));
  }
}
