import 'package:gal/gal.dart';

/// Mobile implementation of video saver.
Future<void> saveVideoFile(String path) async {
  try {
    final hasAccess = await Gal.hasAccess(toAlbum: true);
    if (!hasAccess) {
      await Gal.requestAccess(toAlbum: true);
    }
    await Gal.putVideo(path, album: 'Reaction Studio');
  } on GalException catch (e) {
    throw e.type.message;
  } catch (e) {
    throw e.toString();
  }
}
