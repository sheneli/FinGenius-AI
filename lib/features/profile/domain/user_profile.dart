class UserPrefs {
  const UserPrefs({
    this.theme = 'dark',
    this.currency = 'LKR',
    this.hideBalances = false,
    this.quietStartMin = 22 * 60,
    this.quietEndMin = 7 * 60 + 30,
    this.paydayDay,
  });

  final String theme; // dark | light | system
  final String currency;
  final bool hideBalances;
  final int quietStartMin;
  final int quietEndMin;
  final int? paydayDay; // 1..28, powers payday-aware nudges

  UserPrefs copyWith(
          {String? theme,
          String? currency,
          bool? hideBalances,
          int? quietStartMin,
          int? quietEndMin,
          int? paydayDay}) =>
      UserPrefs(
        theme: theme ?? this.theme,
        currency: currency ?? this.currency,
        hideBalances: hideBalances ?? this.hideBalances,
        quietStartMin: quietStartMin ?? this.quietStartMin,
        quietEndMin: quietEndMin ?? this.quietEndMin,
        paydayDay: paydayDay ?? this.paydayDay,
      );

  Map<String, dynamic> toMap() => {
        'theme': theme,
        'currency': currency,
        'hideBalances': hideBalances,
        'quietStartMin': quietStartMin,
        'quietEndMin': quietEndMin,
        'paydayDay': paydayDay,
      };
  static UserPrefs fromMap(Map<String, dynamic>? m) => m == null
      ? const UserPrefs()
      : UserPrefs(
          theme: (m['theme'] as String?) ?? 'dark',
          currency: (m['currency'] as String?) ?? 'LKR',
          hideBalances: (m['hideBalances'] as bool?) ?? false,
          quietStartMin: (m['quietStartMin'] as num?)?.toInt() ?? 22 * 60,
          quietEndMin: (m['quietEndMin'] as num?)?.toInt() ?? 7 * 60 + 30,
          paydayDay: (m['paydayDay'] as num?)?.toInt(),
        );
}

class UserConsent {
  const UserConsent(
      {this.analytics = false,
      this.aiProcessing = false,
      this.notifications = false,
      this.acceptedAt});
  final bool analytics;
  final bool aiProcessing;
  final bool notifications;
  final DateTime? acceptedAt;

  UserConsent copyWith(
          {bool? analytics,
          bool? aiProcessing,
          bool? notifications,
          DateTime? acceptedAt}) =>
      UserConsent(
        analytics: analytics ?? this.analytics,
        aiProcessing: aiProcessing ?? this.aiProcessing,
        notifications: notifications ?? this.notifications,
        acceptedAt: acceptedAt ?? this.acceptedAt,
      );

  Map<String, dynamic> toMap() => {
        'analytics': analytics,
        'aiProcessing': aiProcessing,
        'notifications': notifications,
        'acceptedAt': acceptedAt?.toUtc().toIso8601String(),
      };
  static UserConsent fromMap(Map<String, dynamic>? m) => m == null
      ? const UserConsent()
      : UserConsent(
          analytics: (m['analytics'] as bool?) ?? false,
          aiProcessing: (m['aiProcessing'] as bool?) ?? false,
          notifications: (m['notifications'] as bool?) ?? false,
          acceptedAt: _parseAcceptedAt(m['acceptedAt']),
        );

  /// Firestore returns a [Timestamp] after the server acknowledges the write,
  /// while the Hive/export representation is an ISO string. Accept both. The
  /// old string cast threw as soon as consent was saved, which took the entire
  /// profile stream down and made every preference switch appear stuck.
  static DateTime? _parseAcceptedAt(Object? value) {
    if (value == null) return null;
    try {
      final dynamic timestamp = value;
      return (timestamp.toDate() as DateTime).toLocal();
    } catch (_) {
      return DateTime.tryParse(value.toString())?.toLocal();
    }
  }
}

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.email,
    this.displayName = '',
    this.phone = '',
    this.photoUrl,
    this.createdAt,
    this.prefs = const UserPrefs(),
    this.consent = const UserConsent(),
    this.schemaVersion = 1,
  });

  final String uid;
  final String email;
  final String displayName;
  final String phone;
  final String? photoUrl;
  final DateTime? createdAt;
  final UserPrefs prefs;
  final UserConsent consent;
  final int schemaVersion;

  UserProfile copyWith({
    String? displayName,
    String? phone,
    String? photoUrl,
    bool clearPhoto = false,
    UserPrefs? prefs,
    UserConsent? consent,
  }) =>
      UserProfile(
        uid: uid,
        email: email,
        displayName: displayName ?? this.displayName,
        phone: phone ?? this.phone,
        photoUrl: clearPhoto ? null : (photoUrl ?? this.photoUrl),
        createdAt: createdAt,
        prefs: prefs ?? this.prefs,
        consent: consent ?? this.consent,
        schemaVersion: schemaVersion,
      );

  Map<String, dynamic> toMap() => {
        'email': email,
        'displayName': displayName,
        'phone': phone,
        if (photoUrl != null) 'photoUrl': photoUrl,
        'prefs': prefs.toMap(),
        'consent': consent.toMap(),
        'schemaVersion': schemaVersion,
      };

  static UserProfile fromMap(String uid, Map<String, dynamic> m) => UserProfile(
        uid: uid,
        email: (m['email'] as String?) ?? '',
        displayName: (m['displayName'] as String?) ?? '',
        phone: (m['phone'] as String?) ?? '',
        photoUrl: m['photoUrl'] as String?,
        createdAt: _parseCreatedAt(m['createdAt']),
        prefs: UserPrefs.fromMap(m['prefs'] as Map<String, dynamic>?),
        consent: UserConsent.fromMap(m['consent'] as Map<String, dynamic>?),
        schemaVersion: (m['schemaVersion'] as num?)?.toInt() ?? 1,
      );

  // createdAt may be a Firestore Timestamp (has toDate()) or an ISO string.
  static DateTime? _parseCreatedAt(Object? v) {
    if (v == null) return null;
    try {
      final dyn = v as dynamic;
      return dyn.toDate() as DateTime; // Firestore Timestamp
    } catch (_) {
      return DateTime.tryParse(v.toString());
    }
  }
}
