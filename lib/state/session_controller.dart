import 'package:flutter/foundation.dart';

import '../data/models/account.dart';
import '../data/repositories/repositories.dart';

//==============================================================================
// SPOCART — Session controller
//------------------------------------------------------------------------------
// Owns the signed-in user: OTP request / verification, business registration
// and sign-out. Screens observe it via ListenableBuilder.
//==============================================================================

class SessionController extends ChangeNotifier {
  SessionController(this._auth);

  final AuthRepository _auth;

  UserSession? _session;
  OtpChallenge? _challenge;
  bool _restored = false;
  bool _busy = false;

  UserSession? get session => _session;
  OtpChallenge? get challenge => _challenge;
  bool get isSignedIn => _session != null;
  bool get isRegistered => _session?.isRegistered ?? false;
  bool get restored => _restored;
  bool get busy => _busy;

  /// Loads a persisted session at startup. Safe to call more than once.
  Future<void> restore() async {
    if (_restored) return;
    try {
      _session = await _auth.restoreSession();
    } catch (_) {
      _session = null;
    }
    _restored = true;
    notifyListeners();
  }

  /// Requests an OTP for [mobile] (10 digits). Throws [AppException].
  Future<OtpChallenge> sendOtp(String mobile) async {
    _setBusy(true);
    try {
      _challenge = await _auth.sendOtp(mobile);
      notifyListeners();
      return _challenge!;
    } finally {
      _setBusy(false);
    }
  }

  /// Verifies [code] for the pending challenge. Throws [AppException].
  Future<UserSession> verifyOtp(String code) async {
    final OtpChallenge? challenge = _challenge;
    if (challenge == null) {
      throw const AppException('Please request an OTP first.');
    }
    _setBusy(true);
    try {
      _session = await _auth.verifyOtp(challenge.mobile, code);
      _challenge = null;
      notifyListeners();
      return _session!;
    } finally {
      _setBusy(false);
    }
  }

  /// Saves the business profile captured on registration / edit profile.
  Future<void> saveProfile(BusinessProfile profile) async {
    final UserSession? current = _session;
    if (current == null) throw const AppException('You are not signed in.');
    _setBusy(true);
    try {
      final UserSession updated = current.copyWith(profile: profile);
      await _auth.saveSession(updated);
      _session = updated;
      notifyListeners();
    } finally {
      _setBusy(false);
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _session = null;
    _challenge = null;
    notifyListeners();
  }

  void _setBusy(bool value) {
    if (_busy == value) return;
    _busy = value;
    notifyListeners();
  }
}
