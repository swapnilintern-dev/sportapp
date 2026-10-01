//==============================================================================
// SPOCART — Account models
//------------------------------------------------------------------------------
// UserSession     — who is signed in (mobile number) + their business profile.
// BusinessProfile — the details captured on "Complete Your Business Details".
// Address         — a saved delivery address.
// All are JSON round-trippable so they survive restarts via LocalStore.
//==============================================================================

enum BusinessType {
  retailer,
  wholesaler,
  academy,
  school,
  club,
  gym,
  corporate,
  other,
}

extension BusinessTypeLabel on BusinessType {
  String get label => switch (this) {
        BusinessType.retailer => 'Retailer / Sports Shop',
        BusinessType.wholesaler => 'Wholesaler / Distributor',
        BusinessType.academy => 'Sports Academy',
        BusinessType.school => 'School / College',
        BusinessType.club => 'Club / Association',
        BusinessType.gym => 'Gym / Fitness Centre',
        BusinessType.corporate => 'Corporate / Institution',
        BusinessType.other => 'Other',
      };

  static BusinessType fromName(String? name) => BusinessType.values.firstWhere(
        (t) => t.name == name,
        orElse: () => BusinessType.other,
      );
}

class BusinessProfile {
  const BusinessProfile({
    required this.businessName,
    required this.gstin,
    required this.businessType,
    required this.contactName,
    required this.mobile,
    required this.email,
  });

  final String businessName;
  final String gstin;
  final BusinessType businessType;
  final String contactName;

  /// 10-digit mobile (no country code).
  final String mobile;
  final String email;

  BusinessProfile copyWith({
    String? businessName,
    String? gstin,
    BusinessType? businessType,
    String? contactName,
    String? mobile,
    String? email,
  }) =>
      BusinessProfile(
        businessName: businessName ?? this.businessName,
        gstin: gstin ?? this.gstin,
        businessType: businessType ?? this.businessType,
        contactName: contactName ?? this.contactName,
        mobile: mobile ?? this.mobile,
        email: email ?? this.email,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'businessName': businessName,
        'gstin': gstin,
        'businessType': businessType.name,
        'contactName': contactName,
        'mobile': mobile,
        'email': email,
      };

  factory BusinessProfile.fromJson(Map<String, dynamic> json) =>
      BusinessProfile(
        businessName: json['businessName'] as String? ?? '',
        gstin: json['gstin'] as String? ?? '',
        businessType:
            BusinessTypeLabel.fromName(json['businessType'] as String?),
        contactName: json['contactName'] as String? ?? '',
        mobile: json['mobile'] as String? ?? '',
        email: json['email'] as String? ?? '',
      );
}

class UserSession {
  const UserSession({
    required this.mobile,
    required this.signedInAt,
    this.profile,
    this.creditLimit = 100000,
  });

  /// 10-digit mobile number used to sign in.
  final String mobile;
  final DateTime signedInAt;

  /// Null until the buyer completes registration ("Skip for now" keeps it null).
  final BusinessProfile? profile;

  /// Business-credit limit granted to this account (Pay Later).
  final double creditLimit;

  bool get isRegistered => profile != null;

  UserSession copyWith({
    String? mobile,
    BusinessProfile? profile,
    double? creditLimit,
  }) =>
      UserSession(
        mobile: mobile ?? this.mobile,
        signedInAt: signedInAt,
        profile: profile ?? this.profile,
        creditLimit: creditLimit ?? this.creditLimit,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'mobile': mobile,
        'signedInAt': signedInAt.toIso8601String(),
        'profile': profile?.toJson(),
        'creditLimit': creditLimit,
      };

  factory UserSession.fromJson(Map<String, dynamic> json) => UserSession(
        mobile: json['mobile'] as String? ?? '',
        signedInAt: DateTime.tryParse(json['signedInAt'] as String? ?? '') ??
            DateTime.now(),
        profile: json['profile'] == null
            ? null
            : BusinessProfile.fromJson(
                Map<String, dynamic>.from(json['profile'] as Map)),
        creditLimit: (json['creditLimit'] as num?)?.toDouble() ?? 100000,
      );
}

enum AddressLabel { home, office, warehouse, ground, other }

extension AddressLabelText on AddressLabel {
  String get label => switch (this) {
        AddressLabel.home => 'Home',
        AddressLabel.office => 'Office',
        AddressLabel.warehouse => 'Warehouse',
        AddressLabel.ground => 'Ground',
        AddressLabel.other => 'Other',
      };

  static AddressLabel fromName(String? name) => AddressLabel.values.firstWhere(
        (l) => l.name == name,
        orElse: () => AddressLabel.other,
      );
}

class Address {
  const Address({
    required this.id,
    required this.contactName,
    required this.line1,
    required this.city,
    required this.state,
    required this.pincode,
    required this.mobile,
    this.businessName = '',
    this.line2 = '',
    this.label = AddressLabel.home,
    this.isDefault = false,
  });

  final String id;
  final String contactName;
  final String businessName;
  final String line1;
  final String line2;
  final String city;
  final String state;
  final String pincode;
  final String mobile;
  final AddressLabel label;
  final bool isDefault;

  /// "ABC Sports, MG Road, Ranchi, Jharkhand - 834001"
  String get summary {
    final List<String> parts = <String>[
      if (businessName.isNotEmpty) businessName,
      line1,
      if (line2.isNotEmpty) line2,
      city,
      '$state - $pincode',
    ];
    return parts.join(', ');
  }

  /// Multi-line form for order details / invoices.
  String get multiline {
    final List<String> parts = <String>[
      if (businessName.isNotEmpty) businessName,
      line1,
      if (line2.isNotEmpty) line2,
      '$city, $state - $pincode',
    ];
    return parts.join('\n');
  }

  Address copyWith({
    String? contactName,
    String? businessName,
    String? line1,
    String? line2,
    String? city,
    String? state,
    String? pincode,
    String? mobile,
    AddressLabel? label,
    bool? isDefault,
  }) =>
      Address(
        id: id,
        contactName: contactName ?? this.contactName,
        businessName: businessName ?? this.businessName,
        line1: line1 ?? this.line1,
        line2: line2 ?? this.line2,
        city: city ?? this.city,
        state: state ?? this.state,
        pincode: pincode ?? this.pincode,
        mobile: mobile ?? this.mobile,
        label: label ?? this.label,
        isDefault: isDefault ?? this.isDefault,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'contactName': contactName,
        'businessName': businessName,
        'line1': line1,
        'line2': line2,
        'city': city,
        'state': state,
        'pincode': pincode,
        'mobile': mobile,
        'label': label.name,
        'isDefault': isDefault,
      };

  factory Address.fromJson(Map<String, dynamic> json) => Address(
        id: json['id'] as String,
        contactName: json['contactName'] as String? ?? '',
        businessName: json['businessName'] as String? ?? '',
        line1: json['line1'] as String? ?? '',
        line2: json['line2'] as String? ?? '',
        city: json['city'] as String? ?? '',
        state: json['state'] as String? ?? '',
        pincode: json['pincode'] as String? ?? '',
        mobile: json['mobile'] as String? ?? '',
        label: AddressLabelText.fromName(json['label'] as String?),
        isDefault: json['isDefault'] as bool? ?? false,
      );
}

const List<String> kIndianStates = <String>[
  'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chhattisgarh',
  'Delhi', 'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jammu & Kashmir',
  'Jharkhand', 'Karnataka', 'Kerala', 'Madhya Pradesh', 'Maharashtra',
  'Manipur', 'Meghalaya', 'Mizoram', 'Nagaland', 'Odisha', 'Punjab',
  'Rajasthan', 'Sikkim', 'Tamil Nadu', 'Telangana', 'Tripura',
  'Uttar Pradesh', 'Uttarakhand', 'West Bengal',
];

enum TeamRole { owner, purchaser, accounts, viewer }

extension TeamRoleLabel on TeamRole {
  String get label => switch (this) {
        TeamRole.owner => 'Owner',
        TeamRole.purchaser => 'Purchaser',
        TeamRole.accounts => 'Accounts',
        TeamRole.viewer => 'Viewer',
      };

  static TeamRole fromName(String? name) => TeamRole.values.firstWhere(
        (r) => r.name == name,
        orElse: () => TeamRole.viewer,
      );
}

/// A colleague who can order on behalf of the business.
class TeamMember {
  const TeamMember({
    required this.id,
    required this.name,
    required this.mobile,
    required this.role,
  });

  final String id;
  final String name;
  final String mobile;
  final TeamRole role;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'mobile': mobile,
        'role': role.name,
      };

  factory TeamMember.fromJson(Map<String, dynamic> json) => TeamMember(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        mobile: json['mobile'] as String? ?? '',
        role: TeamRoleLabel.fromName(json['role'] as String?),
      );
}
