import 'package:flutter/foundation.dart';

import '../data/models/account.dart';
import '../data/repositories/repositories.dart';

//==============================================================================
// SPOCART — Address controller
//------------------------------------------------------------------------------
// Saved delivery addresses with a single default. Persisted locally.
//==============================================================================

class AddressController extends ChangeNotifier {
  AddressController(this._repository);

  final AddressRepository _repository;

  List<Address> _addresses = <Address>[];
  bool _loading = false;
  bool _loaded = false;
  String? _error;

  List<Address> get addresses => List<Address>.unmodifiable(_addresses);
  bool get loading => _loading;
  bool get loaded => _loaded;
  String? get error => _error;
  bool get isEmpty => _addresses.isEmpty;

  Address? get defaultAddress {
    for (final Address a in _addresses) {
      if (a.isDefault) return a;
    }
    return _addresses.isEmpty ? null : _addresses.first;
  }

  Address? byId(String id) {
    for (final Address a in _addresses) {
      if (a.id == id) return a;
    }
    return null;
  }

  Future<void> load({bool force = false}) async {
    if (_loading || (_loaded && !force)) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _addresses = List<Address>.of(await _repository.fetchAddresses());
      _loaded = true;
    } catch (_) {
      _error = 'Could not load your addresses.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Adds or updates [address]. The first address ever saved becomes default.
  Future<Address> save(Address address) async {
    final int i = _addresses.indexWhere((a) => a.id == address.id);
    Address next = address;
    if (_addresses.isEmpty) next = next.copyWith(isDefault: true);
    if (next.isDefault) {
      _addresses =
          _addresses.map((a) => a.copyWith(isDefault: false)).toList();
    }
    if (i >= 0) {
      _addresses[i] = next;
    } else {
      _addresses.add(next);
    }
    notifyListeners();
    await _repository.saveAll(_addresses);
    return next;
  }

  Future<void> setDefault(String id) async {
    _addresses =
        _addresses.map((a) => a.copyWith(isDefault: a.id == id)).toList();
    notifyListeners();
    await _repository.saveAll(_addresses);
  }

  Future<void> remove(String id) async {
    final bool wasDefault = byId(id)?.isDefault ?? false;
    _addresses.removeWhere((a) => a.id == id);
    if (wasDefault && _addresses.isNotEmpty) {
      _addresses[0] = _addresses[0].copyWith(isDefault: true);
    }
    notifyListeners();
    await _repository.saveAll(_addresses);
  }

  void reset() {
    _addresses = <Address>[];
    _loaded = false;
    notifyListeners();
  }
}
