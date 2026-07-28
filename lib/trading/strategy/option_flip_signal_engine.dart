import '../models/candle.dart';
import '../models/option_contract.dart';

enum FlipAction { none, enter, exit }

class FlipEvaluation {
  final FlipAction action;
  final OptionType? side;
  FlipEvaluation(this.action, [this.side]);
}

class OptionFlipSignalEngine {
  OptionType? heldSide;

  FlipEvaluation evaluate({
    required OptionType side,
    required Candle previous,
    required Candle latest,
  }) {
    if (heldSide == null) {
      if (latest.close > previous.high) {
        heldSide = side;
        return FlipEvaluation(FlipAction.enter, side);
      }
      return FlipEvaluation(FlipAction.none);
    }

    if (heldSide == side) {
      if (latest.close < previous.low) {
        heldSide = null;
        return FlipEvaluation(FlipAction.exit, side);
      }
      return FlipEvaluation(FlipAction.none);
    }

    return FlipEvaluation(FlipAction.none);
  }
}