class UserModel {
  int? id;
  String? name;
  String? email; // 🔹 NEW
  String? password; // 🔹 NEW
  String? gender;
  String? bio;
  double? latitude;
  double? longitude;
  String? photoUrl;
  bool? profilVerifie;
  String? preferredGender;
  int? age;
  int? distanceRange;

  UserModel({
    this.id,
    this.name,
    this.email, // 🔹 NEW
    this.password, // 🔹 NEW
    this.gender,
    this.bio,
    this.latitude,
    this.longitude,
    this.photoUrl,
    this.profilVerifie = false,
    this.preferredGender,
    this.age,
    this.distanceRange,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email, // 🔹 NEW
      'password': password, // 🔹 NEW
      'gender': gender,
      'bio': bio,
      'latitude': latitude,
      'longitude': longitude,
      'photo_url': photoUrl,
      'profil_verifie': profilVerifie == true ? 1 : 0,
      'preferred_gender': preferredGender,
      'age': age,
      'distance_range': distanceRange,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'],
      name: map['name'],
      email: map['email'], // 🔹 NEW
      password: map['password'], // 🔹 NEW
      gender: map['gender'],
      bio: map['bio'],
      latitude: map['latitude'],
      longitude: map['longitude'],
      photoUrl: map['photo_url'],
      profilVerifie: map['profil_verifie'] == 1,
      preferredGender: map['preferred_gender'],
      age: map['age'],
      distanceRange: map['distance_range'],
    );
  }
}