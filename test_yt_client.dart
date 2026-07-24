import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:http/http.dart' as http;

void main() async {
  // Try passing different options or see what properties exist
  final yt = YoutubeExplode();
  try {
    print('Searching...');
    final searchResults = await yt.search.search('bettersweet');
    final videoId = searchResults.first.id.value;
    print('Found video: $videoId');

    // youtube_explode_dart 3+ introduced different client types
    final manifest = await yt.videos.streamsClient.getManifest(videoId, ytClients: [YoutubeApiClient.ios]);
    final audioStreams = manifest.audioOnly.where((s) => s.container.name == 'mp4').toList();
    final url = audioStreams.isNotEmpty ? audioStreams.first.url : manifest.audioOnly.first.url;
    
    print('Stream URL: $url');
    print('Testing HTTP GET with NO headers...');
    final response = await http.get(url);
    print('Response status NO headers: ${response.statusCode}');

  } catch (e) {
    print('Error: $e');
  } finally {
    yt.close();
  }
}
