import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class ImageUtils {
  ImageUtils._();

  static Future<File> compressImage(
    String path, {
    int targetWidth = 800,
    int quality = 70,
  }) async {
    final file = File(path);
    final bytes = await file.readAsBytes();

    final compressed = await compute(
      _compressImageIsolate,
      _CompressParams(
        bytes: bytes,
        targetWidth: targetWidth,
        quality: quality,
      ),
    );

    final directory = file.parent;
    final extension = file.path.split('.').last.toLowerCase();
    final compressedFileName =
        '${_fileNameWithoutExtension(file.path)}_compressed.$extension';
    final compressedFile = File('${directory.path}/$compressedFileName');
    await compressedFile.writeAsBytes(compressed);

    return compressedFile;
  }

  static Uint8List _compressImageIsolate(_CompressParams params) {
    final image = img.decodeImage(params.bytes);
    if (image == null) {
      return params.bytes;
    }

    img.Image resized;
    if (image.width > params.targetWidth) {
      resized = img.copyResize(image, width: params.targetWidth);
    } else {
      resized = image;
    }

    return Uint8List.fromList(
      img.encodeJpg(resized, quality: params.quality),
    );
  }

  static Future<String> imageToBase64(String path) async {
    final file = File(path);
    final bytes = await file.readAsBytes();
    return base64Encode(bytes);
  }

  static Future<double> fileSizeInKB(String path) async {
    final file = File(path);
    final stat = await file.stat();
    return stat.size / 1024.0;
  }

  static String _fileNameWithoutExtension(String path) {
    final fileName = path.split(Platform.pathSeparator).last;
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex == -1) return fileName;
    return fileName.substring(0, dotIndex);
  }
}

class _CompressParams {
  final Uint8List bytes;
  final int targetWidth;
  final int quality;

  const _CompressParams({
    required this.bytes,
    required this.targetWidth,
    required this.quality,
  });
}
