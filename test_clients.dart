import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:http/http.dart' as http;

void main() async {
  for (var client in YoutubeApiClient.values) {
    print('\n--- Testing client: ${client.name} ---');
    final yt = YoutubeExplode();
    try {
      final manifest = await yt.videos.streamsClient.getManifest('YcpMVsvK8pk', ytClients: [client]);
      
      final audioStreams = manifest.audioOnly;
      if (audioStreams.isEmpty) {
        print('No audio streams.');
        continue;
      }
      
      final url = audioStreams.first.url;
      final res = await http.get(url);
      print('Status: ${res.statusCode}');
    } catch (e) {
      print('Error: $e');
    } finally {
      yt.close();
    }
  }
}
