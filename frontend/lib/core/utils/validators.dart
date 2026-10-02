/// Small shared validators for forms.
class Validators {
  static String? required(String? value, [String label = 'This field']) {
    if (value == null || value.trim().isEmpty) return '$label is required.';
    return null;
  }

  static String? minLength(String? value, int min, [String label = 'Value']) {
    if (value != null && value.length < min) {
      return '$label must be at least $min characters.';
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return null; // optional
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());
    if (!ok) return 'Enter a valid email address.';
    return null;
  }
}
