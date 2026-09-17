import 'package:flutter/foundation.dart';

import '../data/models/account.dart';
import '../data/repositories/repositories.dart';

//==============================================================================
// SPOCART — Team members controller
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
    } on AppException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Could not load team members.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<TeamMember> add(TeamMember member) async {
    final TeamMember saved = await _repository.add(member);
    _members.add(saved);
    _loaded = true;
    notifyListeners();
    return saved;
  }

  Future<void> remove(String id) async {
    await _repository.remove(id);
    _members.removeWhere((m) => m.id == id);
    notifyListeners();
  }

  void reset() {
    _members = <TeamMember>[];
    _loaded = false;
    notifyListeners();
  }
}
