import 'package:flutter/foundation.dart';

import '../data/models/account.dart';
import '../data/repositories/repositories.dart';

//==============================================================================
// SPOCART — Team members controller
//------------------------------------------------------------------------------
// Colleagues attached to the business account. Persisted per account.
//==============================================================================

class TeamController extends ChangeNotifier {
  TeamController(this._repository);

  final TeamRepository _repository;

  List<TeamMember> _members = <TeamMember>[];
  bool _loading = false;
  bool _loaded = false;
  String? _error;

  List<TeamMember> get members => List<TeamMember>.unmodifiable(_members);
  bool get loading => _loading;
  bool get loaded => _loaded;
  String? get error => _error;

  Future<void> load({bool force = false}) async {
    if (_loading || (_loaded && !force)) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _members = List<TeamMember>.of(await _repository.fetchMembers());
      _loaded = true;
    } catch (_) {
      _error = 'Could not load team members.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> save(TeamMember member) async {
    final int i = _members.indexWhere((m) => m.id == member.id);
    if (i >= 0) {
      _members[i] = member;
    } else {
      _members.add(member);
    }
    notifyListeners();
    await _repository.saveAll(_members);
  }

  Future<void> remove(String id) async {
    _members.removeWhere((m) => m.id == id);
    notifyListeners();
    await _repository.saveAll(_members);
  }

  void reset() {
    _members = <TeamMember>[];
    _loaded = false;
    notifyListeners();
  }
}
