import 'dart:io';
import 'package:http/http.dart' as http;

class SupabaseStorageService {
  static const String supabaseUrl = 'https://ymtngztgkrnxfayvavoe.supabase.co';
  static const String anonKey =
      'sb_publishable_rrZtHSRZZSSq4pCXUCZhfw_aLHISE51';
  static const String bucketName = 'kezcemzek-files';

  // Upload limits conforming to website specification
  static const int maxFileSizeBytes = 10 * 1024 * 1024; // 10 MB
  static const int maxTotalSizeBytes = 25 * 1024 * 1024; // 25 MB
  static const int maxFilesCount = 5;
  static const int maxFilenameLength = 150;
  static const List<String> allowedExtensions = ['pdf', 'png', 'jpg', 'jpeg', 'doc', 'docx'];

  /// Validates a single file against limits
  static String? validateFile(File file, String filename) {
    if (!file.existsSync()) {
      return 'File does not exist.';
    }

    final int size = file.lengthSync();
    if (size == 0) {
      return 'Selected file is empty.';
    }

    if (size > maxFileSizeBytes) {
      return 'File size exceeds 10MB limit (${(size / (1024 * 1024)).toStringAsFixed(1)}MB).';
    }

    final String extension = filename.split('.').last.toLowerCase();
    if (!allowedExtensions.contains(extension)) {
      return 'Unsupported file format ($extension). Allowed formats: PDF, PNG, JPG, JPEG, DOC, DOCX.';
    }

    if (filename.length > maxFilenameLength) {
      return 'Filename is too long (maximum 150 characters).';
    }

    return null;
  }

  /// Sanitizes filename to prevent directory traversal and special character issues
  static String sanitizeFilename(String filename) {
    // Remove unsafe characters, keep alphanumeric, dots, underscores, dashes
    String cleaned = filename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    // Collapse multiple underscores
    cleaned = cleaned.replaceAll(RegExp(r'_+'), '_');
    if (cleaned.length > maxFilenameLength) {
      final ext = cleaned.contains('.') ? '.${cleaned.split('.').last}' : '';
      cleaned = cleaned.substring(0, maxFilenameLength - ext.length) + ext;
    }
    return cleaned;
  }

  /// Uploads a file to Supabase Storage and returns its public URL
  static Future<String> uploadFile({
    required File file,
    required String originalFilename,
    String? orderId,
  }) async {
    final validationError = validateFile(file, originalFilename);
    if (validationError != null) {
      throw Exception(validationError);
    }

    final safeFilename = sanitizeFilename(originalFilename);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final objectPath = 'uploads/${timestamp}_$safeFilename';

    final uri = Uri.parse('$supabaseUrl/storage/v1/object/$bucketName/$objectPath');

    final String ext = safeFilename.split('.').last.toLowerCase();
    String contentType = 'application/octet-stream';
    if (ext == 'pdf') {
      contentType = 'application/pdf';
    } else if (ext == 'png') {
      contentType = 'image/png';
    } else if (ext == 'jpg' || ext == 'jpeg') {
      contentType = 'image/jpeg';
    } else if (ext == 'doc') {
      contentType = 'application/msword';
    } else if (ext == 'docx') {
      contentType = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }

    final bytes = await file.readAsBytes();

    final response = await http.post(
      uri,
      headers: {
        'apikey': anonKey,
        'Authorization': 'Bearer $anonKey',
        'Content-Type': contentType,
        'x-upsert': 'true',
      },
      body: bytes,
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      // Public URL standard format for Supabase Storage
      return '$supabaseUrl/storage/v1/object/public/$bucketName/$objectPath';
    } else {
      throw Exception('Supabase upload failed (${response.statusCode}): ${response.body}');
    }
  }
}
