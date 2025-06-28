import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';

class CloudinaryService {
  static const String cloudName = 'dwbkqxelw'; // ✅ your Cloudinary cloud name
  static const String uploadPreset = 'flutter_unsigned'; // ✅ your preset

  /// Upload an image file to Cloudinary
  static Future<String> uploadImage(File file, {String? folder}) async {
    try {
      final uri = Uri.parse(
          'https://api.cloudinary.com/v1_1/$cloudName/image/upload');

      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset;

      if (folder != null && folder.isNotEmpty) {
        request.fields['folder'] = folder;
      }

      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      final response = await request.send();
      final resBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(resBody);
        return jsonResponse['secure_url'] ?? '';
      } else {
        print('Cloudinary image upload failed: $resBody');
        return '';
      }
    } catch (e) {
      print('Cloudinary image upload error: $e');
      return '';
    }
  }

  /// Upload a video file to Cloudinary
  static Future<String> uploadVideo(File file, {String? folder}) async {
    try {
      final uri = Uri.parse(
          'https://api.cloudinary.com/v1_1/$cloudName/video/upload');
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset;

      if (folder != null && folder.isNotEmpty) {
        request.fields['folder'] = folder;
      }

      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      final response = await request.send();
      final resBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(resBody);
        return jsonResponse['secure_url'] ?? '';
      } else {
        print('Cloudinary video upload failed: $resBody');
        return '';
      }
    } catch (e) {
      print('Cloudinary video upload error: $e');
      return '';
    }
  }
}