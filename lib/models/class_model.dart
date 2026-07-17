class ClassModel {
  const ClassModel({
    required this.id,
    required this.name,
    required this.code,
    required this.createdBy,
    this.viceCode,
    this.isOpen = true,
  });

  final int id;
  final String name;
  final String code;
  final String createdBy;
  final String? viceCode;
  final bool isOpen;

  factory ClassModel.fromMap(Map<String, dynamic> map) {
    return ClassModel(
      id: map['id'] as int,
      name: map['nama_kelas']?.toString() ?? '',
      code: map['kode_kelas']?.toString() ?? '',
      viceCode: map['kode_wakil']?.toString(),
      createdBy: map['created_by']?.toString() ?? '',
      isOpen: map['is_open'] as bool? ?? true,
    );
  }
}
