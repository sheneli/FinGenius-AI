import 'failure.dart';

/// Lightweight Result type: forces callers to handle failure explicitly.
sealed class Result<T> {
  const Result();

  R when<R>({required R Function(T value) ok, required R Function(Failure f) err}) =>
      switch (this) { Ok<T>(:final value) => ok(value), Err<T>(:final failure) => err(failure) };

  T? get valueOrNull => switch (this) { Ok<T>(:final value) => value, Err<T>() => null };
  Failure? get failureOrNull => switch (this) { Ok<T>() => null, Err<T>(:final failure) => failure };
  bool get isOk => this is Ok<T>;

  Result<R> map<R>(R Function(T) f) => switch (this) {
        Ok<T>(:final value) => Ok(f(value)),
        Err<T>(:final failure) => Err(failure),
      };
}

class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

class Err<T> extends Result<T> {
  const Err(this.failure);
  final Failure failure;
}

/// Runs [body], converting thrown exceptions into an [Err] via [onError].
Future<Result<T>> guard<T>(Future<T> Function() body, {Failure Function(Object e, StackTrace st)? onError}) async {
  try {
    return Ok(await body());
  } catch (e, st) {
    return Err(onError?.call(e, st) ?? UnknownFailure('Something went wrong. Please try again.', cause: e));
  }
}
