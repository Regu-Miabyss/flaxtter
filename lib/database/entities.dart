class Account {
  final String id;
  final String screenName;
  final String authHeader;

  Account({required this.id, required this.screenName, required this.authHeader});

  factory Account.fromMap(Map<String, Object?> map) {
    return Account(
      id: map['id'] as String,
      screenName: map['screen_name'] as String,
      authHeader: map['auth_header'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'screen_name': screenName, 'auth_header': authHeader};
  }
}
