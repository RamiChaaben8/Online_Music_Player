import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() async {
  final yt = YoutubeExplode();
  try {
    final pl = await yt.playlists.get('PLRBp0Fe2GpgnIh0AiYKh7o7HnYAej-5ph');
    int count = 0;
    await for (var v in yt.playlists.getVideos(pl.id)) {
      count++;
    }
    print('YT Explode got: $count');
  } catch (e) {
    print('Error: $e');
  } finally {
    yt.close();
  }
}
