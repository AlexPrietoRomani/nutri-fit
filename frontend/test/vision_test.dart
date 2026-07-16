import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nutrifit/features/ai/ai_config.dart';
import 'package:nutrifit/features/ai/vision_service.dart';

void main() {
  group('VisionService', () {
    test('analyzeMeal sube multipart con el campo ai y parsea la respuesta', () async {
      final mock = MockClient((req) async {
        expect(req.url.path, endsWith('/analyze-meal'));
        // El body multipart incluye el campo "ai" con la config del proveedor.
        expect(req.body, contains('ollama'));
        return http.Response(
          jsonEncode({'food_items': ['huevo'], 'calories': 140}), 200,
          headers: {'content-type': 'application/json'},
        );
      });
      final svc = VisionService(httpClient: mock);
      final img = XFile.fromData(Uint8List.fromList([1, 2, 3]), name: 'meal.jpg');
      final data = await svc.analyzeMeal(img, AIConfig(provider: 'ollama', model: 'llava'));
      expect(data['food_items'], ['huevo']);
      expect(data['calories'], 140);
    });

    test('identifyMachine golpea /identify-machine y funciona sin AIConfig', () async {
      final mock = MockClient((req) async {
        expect(req.url.path, endsWith('/identify-machine'));
        return http.Response(jsonEncode({'machine_name': 'Leg Press'}), 200,
            headers: {'content-type': 'application/json'});
      });
      final svc = VisionService(httpClient: mock);
      final img = XFile.fromData(Uint8List.fromList([9, 9]), name: 'm.jpg');
      final data = await svc.identifyMachine(img, null); // sin config
      expect(data['machine_name'], 'Leg Press');
    });

    test('un error HTTP lanza excepción', () async {
      final mock = MockClient((req) async => http.Response('boom', 503));
      final svc = VisionService(httpClient: mock);
      final img = XFile.fromData(Uint8List.fromList([1]), name: 'm.jpg');
      expect(
        () => svc.analyzeMeal(img, null),
        throwsA(isA<Exception>()),
      );
    });
  });
}
