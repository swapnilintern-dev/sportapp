import 'package:flutter/foundation.dart';

import '../data/models/account.dart';
import '../data/repositories/repositories.dart';

//==============================================================================
// SPOCART — Address controller
//------------------------------------------------------------------------------
// Saved delivery addresses with a single default.
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
    } on AppException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Could not load your addresses.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Adds or updates [address]. Throws [AppException].
  Future<Address> save(Address address) async {
    final Address saved = await _repository.save(address);
    if (saved.isDefault) {
      _addresses = _addresses.map((a) => a.copyWith(isDefault: false)).toList();
    }
    final int i = _addresses.indexWhere((a) => a.id == saved.id || a.id == address.id);
    if (i >= 0) {
      _addresses[i] = saved;
    } else {
      _addresses.add(saved);
    }
    if (_addresses.length == 1 && !_addresses.first.isDefault) {
      _addresses[0] = _addresses.first.copyWith(isDefault: true);
    }
    _loaded = true;
    notifyListeners();
    return saved;
  }

  Future<void> setDefault(String id) async {
    await _repository.setDefault(id);
    _addresses = _addresses.map((a) => a.copyWith(isDefault: a.id == id)).toList();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    await _repository.remove(id);
    final bool wasDefault = byId(id)?.isDefault ?? false;
    _addresses.removeWhere((a) => a.id == id);
    if (wasDefault && _addresses.isNotEmpty) {
      _addresses[0] = _addresses[0].copyWith(isDefault: true);
    }
    notifyListeners();
  }

  /// City and state behind a PIN code. Read-through: nothing on this controller
  /// changes, so the form owns the result and the buyer can still edit it.
  Future<PincodeLocation> lookupPincode(String pincode) =>
      _repository.lookupPincode(pincode);

  void reset() {
    _addresses = <Address>[];
    _loaded = false;
    notifyListeners();
  }
}
