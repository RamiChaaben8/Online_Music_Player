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
    final urlAudio = audioStreams.isNotEmpty ? audioStreams.first.url : manifest.audioOnly.first.url;
    
    print('Testing audioOnly stream...');
    final responseAudio = await http.get(urlAudio);
    print('Response status audioOnly: ${responseAudio.statusCode}');

    print('Testing muxed stream...');
    final urlMuxed = manifest.muxed.first.url;
    final responseMuxed = await http.get(urlMuxed);
    print('Response status muxed: ${responseMuxed.statusCode}');

  } catch (e) {
    print('Error: $e');
  } finally {
    yt.close();
  }
}
