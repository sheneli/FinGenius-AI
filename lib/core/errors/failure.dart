/// Typed failures. Every recoverable error in the app is one of these —
/// screens can render precise, actionable messages instead of raw exceptions.
sealed class Failure {
  const Failure(this.message, {this.cause});
  final String message;
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message';
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No connection. Changes will sync when you are back online.']);
}

class AuthFailure extends Failure {
  const AuthFailure(super.message, {this.code, super.cause});
  final String? code;
}

class PermissionFailure extends Failure {
  const PermissionFailure(super.message, {super.cause});
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {this.field, super.cause});
  final String? field;
}

class StorageFailure extends Failure {
  const StorageFailure(super.message, {super.cause});
}

class AiFailure extends Failure {
  const AiFailure(super.message, {this.retriable = false, super.cause});
  final bool retriable;
}

class RateLimitFailure extends Failure {
  const RateLimitFailure([super.message = 'You have reached the AI usage limit for now. Try again later.']);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'Item not found.']);
}

class UnknownFailure extends Failure {
  const UnknownFailure(super.message, {super.cause});
}
