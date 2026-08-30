import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/remedy.dart';
import '../models/user_profile.dart';

class AppStore extends ChangeNotifier {
  UserProfile _profile = const UserProfile();
  bool _premium = false;
  int _checksUsed = 0;
  final List<Remedy> _cart = [];

  UserProfile get profile => _profile;
  bool get isPremium => _premium;
  int get checksUsed => _checksUsed;
  int get checksRemaining {
    if (_premium) return 999;
    return (3 - _checksUsed).clamp(0, 3).toInt();
  }

  List<Remedy> get cart => List.unmodifiable(_cart);
  int get cartCount => _cart.length;
  int get cartTotalCents =>
      _cart.fold(0, (total, remedy) => total + remedy.priceCents);

  bool get canCheck => _premium || _checksUsed < 3;

  Future<void> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final profileJson = preferences.getString('profile');
      if (profileJson != null) {
        _profile = UserProfile.fromJson(
          Map<String, Object?>.from(jsonDecode(profileJson) as Map),
        );
      }
      _premium = preferences.getBool('premium') ?? false;
      _checksUsed = preferences.getInt('checksUsed') ?? 0;
    } catch (_) {
      // The app remains fully usable when local storage is unavailable.
    }
  }

  void updateProfile(UserProfile profile) {
    _profile = profile;
    notifyListeners();
    _persist();
  }

  void setPremium(bool value) {
    _premium = value;
    notifyListeners();
    _persist();
  }

  bool recordCheck() {
    if (!canCheck) return false;
    if (!_premium) _checksUsed++;
    notifyListeners();
    _persist();
    return true;
  }

  void addToCart(Remedy remedy) {
    if (_cart.every((item) => item.id != remedy.id)) {
      _cart.add(remedy);
      notifyListeners();
    }
  }

  void removeFromCart(Remedy remedy) {
    _cart.removeWhere((item) => item.id == remedy.id);
    notifyListeners();
  }

  void clearCart() {
    _cart.clear();
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('profile', jsonEncode(_profile.toJson()));
      await preferences.setBool('premium', _premium);
      await preferences.setInt('checksUsed', _checksUsed);
    } catch (_) {
      // App remains functional without persistence; data will reset on restart.
    }
  }
}
