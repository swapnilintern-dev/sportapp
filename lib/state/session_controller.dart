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

  /// Loads the cached session at startup, then refreshes it from the server
  /// in the background (profile / credit limit may have changed).
  Future<void> restore() async {
    if (_restored) return;
    try {
      _session = await _auth.restoreSession();
    } catch (_) {
      _session = null;
    }
    _restored = true;
    notifyListeners();
    if (_session != null) refresh();
  }

  Future<void> refresh() async {
    try {
      final UserSession? fresh = await _auth.refreshSession();
      if (fresh != null && _session != null) {
        _session = fresh;
        notifyListeners();
      }
    } catch (_) {
      // Offline: keep what we have.
    }
  }

  /// Called by the API client on a 401: the token is gone server-side.
  void expire() {
    if (_session == null) return;
    _session = null;
    _challenge = null;
    _mobileChange = null;
    notifyListeners();
  }

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

  Future<void> saveProfile(BusinessProfile profile) async {
    if (_session == null) throw const AppException('You are not signed in.');
    _setBusy(true);
    try {
      _session = await _auth.saveProfile(profile);
      notifyListeners();
    } finally {
      _setBusy(false);
    }
  }

  //----------------------------------------------------------------------------
  // Changing the registered mobile number
  //----------------------------------------------------------------------------
  // Kept apart from [challenge], which belongs to sign-in: a code sent to a new
  // number must never be able to complete a login, or the other way round.

  OtpChallenge? _mobileChange;
  OtpChallenge? get mobileChangeChallenge => _mobileChange;

  Future<OtpChallenge> requestMobileChange(String newMobile) async {
    if (_session == null) throw const AppException('You are not signed in.');
    _setBusy(true);
    try {
      _mobileChange = await _auth.requestMobileChange(newMobile);
      notifyListeners();
      return _mobileChange!;
    } finally {
      _setBusy(false);
    }
  }

  /// Verifies the code sent to the new number. The session (and, with the API,
  /// the token) is replaced only on success.
  Future<UserSession> confirmMobileChange(String code) async {
    final OtpChallenge? challenge = _mobileChange;
    if (challenge == null) {
      throw const AppException('Please request an OTP first.');
    }
    _setBusy(true);
    try {
      _session = await _auth.confirmMobileChange(challenge.mobile, code);
      _mobileChange = null;
      notifyListeners();
      return _session!;
    } finally {
      _setBusy(false);
    }
  }

  void cancelMobileChange() {
    if (_mobileChange == null) return;
    _mobileChange = null;
    notifyListeners();
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } finally {
      _session = null;
      _challenge = null;
      _mobileChange = null;
      notifyListeners();
    }
  }

  /// Closes the account for good. Unlike [signOut], a failure is rethrown
  /// rather than swallowed: the buyer must never be told their account is gone
  /// when the server never agreed to it.
  Future<void> deleteAccount() async {
    await _auth.deleteAccount();
    _session = null;
    _challenge = null;
    _mobileChange = null;
    notifyListeners();
  }

  void _setBusy(bool value) {
    if (_busy == value) return;
    _busy = value;
    notifyListeners();
  }
}
