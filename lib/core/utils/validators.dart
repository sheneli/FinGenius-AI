/// Input validation used by forms. Returns null when valid (Flutter convention).
class Validators {
  Validators._();

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    final re = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');
    if (!re.hasMatch(v.trim())) return 'Enter a valid email address';
    return null;
  }

  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'Use at least 8 characters';
    if (!RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)) {
      return 'Use letters and at least one number';
    }
    return null;
  }

  static String? requiredField(String? v, [String label = 'This field']) =>
      (v == null || v.trim().isEmpty) ? '$label is required' : null;

  static String? amount(String? v) {
    if (v == null || v.trim().isEmpty) return 'Amount is required';
    final cleaned = v.replaceAll(RegExp(r'[^\d.]'), '');
    final parsed = double.tryParse(cleaned);
    if (parsed == null || parsed <= 0) return 'Enter an amount greater than zero';
    if (parsed > 1000000000) return 'Amount is unrealistically large';
    return null;
  }

  static String? name(String? v) {
    if (v == null || v.trim().isEmpty) return 'Name is required';
    if (v.trim().length > 60) return 'Keep it under 60 characters';
    return null;
  }
}
