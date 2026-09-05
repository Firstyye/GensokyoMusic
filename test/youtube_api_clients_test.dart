import 'package:flutter_test/flutter_test.dart';
import 'package:yo/services/youtube_api_clients.dart';

void main() {
  test('uses VisionOS client for logged-out media streams', () {
    final client = youtubeVisionOsClient;
    final context = client.payload['context'] as Map<String, dynamic>;
    final clientData = context['client'] as Map<String, dynamic>;

    expect(clientData['clientName'], 'VISIONOS');
    expect(clientData['clientVersion'], '1.02');
    expect(clientData['deviceModel'], 'RealityDevice17,1');
    expect(clientData['osName'], 'visionOS');
  });
}
