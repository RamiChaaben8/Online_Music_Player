import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/library_service.dart';

class GuestSessionNotifier extends StateNotifier<bool> {
  GuestSessionNotifier(bool initialState) : super(initialState);

  static const _storageKey = 'guest_session_active';

  Future<void> enterGuest() async {
    LibraryService.setGuestMode(true);
    state = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_storageKey, true);
  }

  Future<void> leaveGuest() async {
    LibraryService.setGuestMode(false);
    state = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  static Future<bool> restore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_storageKey) ?? false;
  }
}

final guestSessionProvider =
    StateNotifierProvider<GuestSessionNotifier, bool>((ref) {
  return GuestSessionNotifier(false);
});
