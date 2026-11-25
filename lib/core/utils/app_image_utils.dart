import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Resolves profile / document images whether stored as HTTP(S) URLs
/// or Base64 Data URIs (`data:image/jpeg;base64,...`).
class AppImageUtils {
  static Uint8List? decodeBase64Image(String? source) {
    if (source == null || source.trim().isEmpty) return null;
    final trimmed = source.trim();
    if (!trimmed.startsWith('data:image/')) return null;
    final commaIdx = trimmed.indexOf(',');
    if (commaIdx == -1 || commaIdx + 1 >= trimmed.length) return null;
    try {
      final raw = trimmed.substring(commaIdx + 1).replaceAll(RegExp(r'\s+'), '');
      return base64Decode(raw);
    } catch (_) {
      return null;
    }
  }

  static ImageProvider? getImageProvider(String? source) {
    if (source == null || source.trim().isEmpty) return null;
    final trimmed = source.trim();
    if (trimmed.startsWith('data:image/')) {
      final bytes = decodeBase64Image(trimmed);
      if (bytes != null) return MemoryImage(bytes);
      return null;
    }
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return NetworkImage(trimmed);
    }
    return null;
  }

  static Widget buildAvatarImage({
    required String? source,
    double size = 64,
    double iconSize = 36,
    Color iconColor = Colors.white,
    BoxFit fit = BoxFit.cover,
  }) {
    final fallback = Icon(Icons.person_rounded, color: iconColor, size: iconSize);
    if (source == null || source.trim().isEmpty) return fallback;
    final trimmed = source.trim();

    if (trimmed.startsWith('data:image/')) {
      final bytes = decodeBase64Image(trimmed);
      if (bytes == null) return fallback;
      return Image.memory(
        bytes,
        width: size,
        height: size,
        fit: fit,
        errorBuilder: (_, _, _) => fallback,
      );
    }

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return Image.network(
        trimmed,
        width: size,
        height: size,
        fit: fit,
        errorBuilder: (_, _, _) => fallback,
      );
    }

    return fallback;
  }
}
