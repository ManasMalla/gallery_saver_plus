import 'dart:async';
import 'dart:io';

import 'package.flutter/services.dart';
import 'package:gallery_saver_plus/files.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';

// Define the callback type
typedef ProgressCallback = void Function(int received, int total);

class GallerySaver {
  static const String channelName = 'gallery_saver';
  static const String methodSaveImage = 'saveImage';
  static const String methodSaveVideo = 'saveVideo';

  static const String pleaseProvidePath = 'Please provide valid file path.';
  static const String fileIsNotVideo = 'File on path is not a video.';
  static const String fileIsNotImage = 'File on path is not an image.';
  static const MethodChannel _channel = const MethodChannel(channelName);

  ///saves video from provided temp path and optional album name in gallery
  static Future<bool?> saveVideo(
    String path, {
    String? albumName,
    bool toDcim = false,
    Map<String, String>? headers,
    ProgressCallback? progressCallback, // New callback parameter
  }) async {
    File? tempFile;
    if (path.isEmpty) {
      throw ArgumentError(pleaseProvidePath);
    }
    if (!isVideo(path)) {
      throw ArgumentError(fileIsNotVideo);
    }
    if (!isLocalFilePath(path)) {
      tempFile = await _downloadFile(
        path,
        headers: headers,
        progressCallback: progressCallback, // Pass it down
      );
      path = tempFile.path;
    }
    bool? result = await _channel.invokeMethod(
      methodSaveVideo,
      <String, dynamic>{'path': path, 'albumName': albumName, 'toDcim': toDcim},
    );
    if (tempFile != null) {
      tempFile.delete();
    }
    return result;
  }

  ///saves image from provided temp path and optional album name in gallery
  static Future<bool?> saveImage(
    String path, {
    String? albumName,
    bool toDcim = false,
    Map<String, String>? headers,
    ProgressCallback? progressCallback, // New callback parameter
  }) async {
    File? tempFile;
    if (path.isEmpty) {
      throw ArgumentError(pleaseProvidePath);
    }
    if (!isImage(path)) {
      throw ArgumentError(fileIsNotImage);
    }
    if (!isLocalFilePath(path)) {
      tempFile = await _downloadFile(
        path,
        headers: headers,
        progressCallback: progressCallback, // Pass it down
      );
      path = tempFile.path;
    }

    bool? result = await _channel.invokeMethod(
      methodSaveImage,
      <String, dynamic>{'path': path, 'albumName': albumName, 'toDcim': toDcim},
    );
    if (tempFile != null) {
      tempFile.delete();
    }

    return result;
  }

  // --- THIS FUNCTION IS REWRITTEN ---
  static Future<File> _downloadFile(
    String url, {
    Map<String, String>? headers,
    ProgressCallback? progressCallback,
  }) async {
    print(url);
    print(headers);
    final client = http.Client();
    final request = http.Request('GET', Uri.parse(url));
    if (headers != null) {
      request.headers.addAll(headers);
    }
    final response = await client.send(request);

    if (response.statusCode >= 400) {
      throw HttpException(response.statusCode.toString());
    }

    // Get the total length of the file
    final totalBytes = response.contentLength ?? -1;
    var receivedBytes = 0;

    // Get the temporary file path
    String dir = (await getTemporaryDirectory()).path;
    String cleanUrl = url.split('?').first;
    File file = new File('$dir/${basename(cleanUrl)}');

    // Open a sink to write the file in chunks
    final sink = file.openWrite();
    final completer = Completer<void>();

    // Listen to the stream of byte chunks
    response.stream.listen(
      (chunk) {
        // Write the chunk to the file
        sink.add(chunk);
        
        // Update the received bytes count
        receivedBytes += chunk.length;

        // Call the progress callback
        progressCallback?.call(receivedBytes, totalBytes);
      },
      onDone: () async {
        // Close the sink and complete the future
        await sink.close();
        completer.complete();
      },
      onError: (e) {
        // Handle stream errors
        sink.close();
        completer.completeError(e);
      },
      cancelOnError: true,
    );

    // Wait for the stream to finish
    await completer.future;

    print('File size:${await file.length()}');
    print(file.path);
    client.close();
    return file;
  }
}
