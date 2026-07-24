import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:http/http.dart' as http;

void main() async {
  final yt = YoutubeExplode();
  try {
    print('Searching...');
    final searchResults = await yt.search.search('bettersweet');
    final videoId = searchResults.first.id.value;
    print('Found video: $videoId');

    final manifest = await yt.videos.streamsClient.getManifest(videoId);
    final audioStreams = manifest.audioOnly.where((s) => s.container.name == 'mp4').toList();
    final url = audioStreams.isNotEmpty ? audioStreams.first.url : manifest.audioOnly.first.url;
    
    print('Stream URL: $url');
    print('Testing HTTP GET with NO headers...');
    final response = await http.get(url);
    print('Response status NO headers: ${response.statusCode}');

    print('Testing HTTP GET with Android ExoPlayer User-Agent...');
    final responseExo = await http.get(url, headers: {
      'User-Agent': 'ExoPlayer',
    });
    print('Response status ExoPlayer: ${responseExo.statusCode}');

  } catch (e) {
    print('Error: $e');
  } finally {
    yt.close();
  }
}
