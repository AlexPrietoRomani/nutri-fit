import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../core/constants.dart';
import 'ai_config.dart';

/// Cliente de los endpoints de visión del ai_service (/analyze-meal,
/// /identify-machine). Sube la imagen por multipart y adjunta la AIConfig del
/// usuario para usar la visión multi-proveedor (con fallback backend a mock).
class VisionService {
  final http.Client _http;

  VisionService({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  Future<Map<String, dynamic>> _post(String path, XFile image, AIConfig? cfg) async {
    final req = http.MultipartRequest('POST', Uri.parse('${AppConstants.aiServiceUrl}$path'));
    final bytes = await image.readAsBytes();
    req.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: image.name.isEmpty ? 'image.jpg' : image.name,
    ));
    if (cfg != null) {
      req.fields['ai'] = jsonEncode(cfg.toJson());
    }
    final streamed = await _http.send(req);
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode != 200) {
      throw Exception('Error ${resp.statusCode}: ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  /// Analiza una foto de comida → {food_items, calories, protein, carbohydrates, fat, ...}
  Future<Map<String, dynamic>> analyzeMeal(XFile image, AIConfig? cfg) =>
      _post('/analyze-meal', image, cfg);

  /// Identifica una máquina → {machine_name, description, target_muscles, associated_exercises, safety_tips, ...}
  Future<Map<String, dynamic>> identifyMachine(XFile image, AIConfig? cfg) =>
      _post('/identify-machine', image, cfg);
}
