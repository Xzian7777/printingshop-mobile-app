import 'package:flutter/material.dart';

class AppValidators {
  // 1. Required Field Validation
  static String? requiredField(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Hindi pwedeng iwang blangko ang $fieldName.';
    }
    return null;
  }

  // 2 & 3. Name Validation (Hindi pwede 1 character lang, min: 2, max: 50)
  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Mangyaring ilagay ang iyong buong pangalan.';
    }
    final trimmed = value.trim();
    if (trimmed.length < 2) {
      return 'Ang pangalan ay dapat higit sa 1 character.';
    }
    if (trimmed.length > 50) {
      return 'Ang pangalan ay hindi pwedeng lumagpas sa 50 characters.';
    }
    final nameRegExp = RegExp(r"^[a-zA-Z\s\-\.\ñ\Ñ]+$");
    if (!nameRegExp.hasMatch(trimmed)) {
      return 'Lihis o bawal na character sa pangalan.';
    }
    return null;
  }

  // 4. Email Validation
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required ang email address.';
    }
    final emailRegExp = RegExp(
      r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$",
    );
    if (!emailRegExp.hasMatch(value.trim())) {
      return 'Maglagay ng tamang email format (hal. name@domain.com).';
    }
    return null;
  }

  // 5. Contact Number Validation (PH 11-digit format: 09XXXXXXXXX)
  static String? validateContactNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required ang contact number.';
    }
    final cleaned = value.trim();
    final phoneRegExp = RegExp(r"^09\d{9}$");
    if (!phoneRegExp.hasMatch(cleaned)) {
      return 'Dapat ay 11-digit PH mobile number (hal. 09123456789).';
    }
    return null;
  }

  // 6. Number Field Validation (Qty / Amount)
  static String? validateNumber(String? value, {num? min, num? max, String fieldName = 'Bilang'}) {
    if (value == null || value.trim().isEmpty) {
      return 'Required ang $fieldName.';
    }
    final numValue = num.tryParse(value.trim());
    if (numValue == null) {
      return 'Maglagay ng tamang numero lang.';
    }
    if (min != null && numValue < min) {
      return 'Ang $fieldName ay hindi pwedeng mababa sa $min.';
    }
    if (max != null && numValue > max) {
      return 'Ang $fieldName ay hindi pwedeng lumagpas sa $max.';
    }
    return null;
  }

  // 7. Password Validation (Min 6 chars, Max 32 chars)
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Required ang password.';
    }
    if (value.length < 6) {
      return 'Ang password ay dapat may minimum na 6 characters.';
    }
    if (value.length > 32) {
      return 'Ang password ay hindi pwedeng lumagpas sa 32 characters.';
    }
    return null;
  }

  // 8. Date Validation
  static String? validateDate(DateTime? selectedDate) {
    if (selectedDate == null) {
      return 'Mangyaring pumili ng petsa.';
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final chosen = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

    if (chosen.isBefore(today)) {
      return 'Hindi pwedeng lumipas na petsa ang piliin.';
    }
    return null;
  }
}