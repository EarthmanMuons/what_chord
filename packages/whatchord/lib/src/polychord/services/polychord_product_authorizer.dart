import '../models/polychord_product_decision.dart';
import '../models/polychord_product_output.dart';

/// Stateless outer authorization reducer for `polychord-output/3`.
final class PolychordProductAuthorizer {
  const PolychordProductAuthorizer();

  PolychordProductAuthorization authorize({
    required bool primaryDisplayable,
    required PolychordOnsetRegisterDecision decision,
  }) {
    if (!primaryDisplayable) {
      return PolychordProductAuthorization(
        key: null,
        reasonCode: 'primary-not-displayable',
      );
    }
    final binding = decision.selectedBinding;
    if (binding == null) {
      return PolychordProductAuthorization(
        key: null,
        reasonCode: decision.reasonCode,
      );
    }
    if (!binding.isComplete) {
      throw StateError('a selected candidate must have a complete binding');
    }
    return PolychordProductAuthorization(
      key: PolychordProductAuthorizationKey(binding: binding),
      reasonCode: null,
    );
  }
}
