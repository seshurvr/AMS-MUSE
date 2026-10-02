import 'dart:typed_data';

import '../core/networking/api_client.dart';
import '../models/class_room.dart';

/// Class CRUD + class-scoped student import/export.
class ClassService {
  ClassService(this._api);

  final ApiClient _api;

  Future<List<ClassRoom>> list({String? search}) async {
    final query = <String, String>{};
    if (search != null && search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }
    final json = await _api.get('/api/classes', query: query) as List<dynamic>;
    return json
        .map((e) => ClassRoom.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ClassRoom> get(int id) async {
    final json = await _api.get('/api/classes/$id') as Map<String, dynamic>;
    return ClassRoom.fromJson(json);
  }

  Future<ClassRoom> create({
    required String name,
    required String section,
    required String subject,
    required String academicYear,
  }) async {
    final json = await _api.post('/api/classes', body: {
      'name': name.trim(),
      'section': section.trim(),
      'subject': subject.trim(),
      'academic_year': academicYear.trim(),
    }) as Map<String, dynamic>;
    return ClassRoom.fromJson(json);
  }

  Future<ClassRoom> update(int id,
      {String? name,
      String? section,
      String? subject,
      String? academicYear,
      String? status}) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name.trim();
    if (section != null) body['section'] = section.trim();
    if (subject != null) body['subject'] = subject.trim();
    if (academicYear != null) body['academic_year'] = academicYear.trim();
    if (status != null) body['status'] = status;
    final json = await _api.put('/api/classes/$id', body: body)
        as Map<String, dynamic>;
    return ClassRoom.fromJson(json);
  }

  Future<void> archive(int id) => _api.delete('/api/classes/$id');
}
