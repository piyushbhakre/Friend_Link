class UserModel {
  final String uid;
  final String phoneNumber;
  final String name;
  final String about;
  final String profileImageUrl;
  final DateTime createdAt;
  final String fcmToken;

  UserModel({
    required this.uid,
    required this.phoneNumber,
    required this.name,
    required this.about,
    required this.profileImageUrl,
    required this.createdAt,
    this.fcmToken = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'phoneNumber': phoneNumber,
      'name': name,
      'about': about,
      'profileImageUrl': profileImageUrl,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'fcmToken': fcmToken,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      name: map['name'] ?? '',
      about: map['about'] ?? '',
      profileImageUrl: map['profileImageUrl'] ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      fcmToken: map['fcmToken'] ?? '',
    );
  }

  UserModel copyWith({
    String? uid,
    String? phoneNumber,
    String? name,
    String? about,
    String? profileImageUrl,
    DateTime? createdAt,
    String? fcmToken,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      name: name ?? this.name,
      about: about ?? this.about,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      createdAt: createdAt ?? this.createdAt,
      fcmToken: fcmToken ?? this.fcmToken,
    );
  }
}