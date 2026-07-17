class LecturerAccountRequest {
  const LecturerAccountRequest({
    required this.name,
    required this.lecturerNumber,
    required this.email,
    required this.password,
  });

  final String name;
  final String lecturerNumber;
  final String email;
  final String password;

  Map<String, String> toMap() => {
    'name': name.trim(),
    'lecturerNumber': lecturerNumber.trim(),
    'email': email.trim().toLowerCase(),
    'password': password,
  };
}
