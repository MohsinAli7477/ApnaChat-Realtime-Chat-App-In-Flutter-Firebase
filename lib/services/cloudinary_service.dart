import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class CloudinaryService {
  static const String cloudName = 'dwbkqxelw';
  static const String uploadPreset = 'flutter_unsigned';

  static Future<String> uploadImage(File file, {String? folder}) async {
    try {
      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');

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
        print('Cloudinary upload failed: $resBody');
        return '';
      }
    } catch (e) {
      print('Cloudinary upload error: $e');
      return '';
    }
  }
}
