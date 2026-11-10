
class AppValidators {
  // 1. Required Field Validation
  static String? requiredField(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required.';
    }
    return null;
  }

  // 2 & 3. Name Validation (Hindi pwede 1 character lang, min: 2, max: 50)
  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your full name.';
    }
    final trimmed = value.trim();
    if (trimmed.length < 2) {
      return 'Name must contain at least 2 characters.';
    }
    if (trimmed.length > 50) {
      return 'Name must not exceed 50 characters.';
    }
    final nameRegExp = RegExp(r"^[a-zA-Z\s\-\.\ñ\Ñ]+$");
    if (!nameRegExp.hasMatch(trimmed)) {
      return 'Name contains an invalid character.';
    }
    return null;
  }

  // 4. Email Validation
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email address is required.';
    }
    final emailRegExp = RegExp(
      r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$",
    );
    if (!emailRegExp.hasMatch(value.trim())) {
      return 'Enter a valid email address (for example, name@domain.com).';
    }
    return null;
  }

  // 5. Contact Number Validation (PH 11-digit format: 09XXXXXXXXX)
  static String? validateContactNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Contact number is required.';
    }
    final cleaned = value.trim();
    final phoneRegExp = RegExp(r"^09\d{9}$");
    if (!phoneRegExp.hasMatch(cleaned)) {
      return 'Enter an 11-digit Philippine mobile number (for example, 09123456789).';
    }
    return null;
  }

  // 6. Number Field Validation (Qty / Amount)
  static String? validateNumber(String? value, {num? min, num? max, String fieldName = 'Bilang'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required.';
    }
    final numValue = num.tryParse(value.trim());
    if (numValue == null) {
      return 'Enter a valid number.';
    }
    if (min != null && numValue < min) {
      return '$fieldName must be at least $min.';
    }
    if (max != null && numValue > max) {
      return '$fieldName must not exceed $max.';
    }
    return null;
  }

  // 7. Password Validation (Min 6 chars, Max 32 chars)
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required.';
    }
    if (value.length < 6) {
      return 'Password must contain at least 6 characters.';
    }
    if (value.length > 32) {
      return 'Password must not exceed 32 characters.';
    }
    return null;
  }

  // 8. Date Validation
  static String? validateDate(DateTime? selectedDate) {
    if (selectedDate == null) {
      return 'Please select a date.';
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final chosen = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

    if (chosen.isBefore(today)) {
      return 'Please select today or a future date.';
    }
    return null;
  }
}