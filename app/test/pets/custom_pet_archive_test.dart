import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:dsh_app/pets/custom_pets.dart';
import 'package:dsh_app/pets/pet_state.dart';
import 'package:flutter_test/flutter_test.dart';

List<int> zip(Map<String, Object?> entries) {
  final archive = Archive();
  for (final entry in entries.entries) {
    final bytes = entry.value is String ? utf8.encode(entry.value as String) : entry.value as List<int>;
    archive.addFile(ArchiveFile(entry.key, bytes.length, bytes));
  }
  return ZipEncoder().encode(archive) ?? [];
}

String manifest() => jsonEncode({
  'schema': 1, 'id': 'external', 'name': 'Pack', 'pixelArt': false,
  'canvas': {'w': 1, 'h': 1}, 'contentBox': {'x': 0, 'y': 0, 'w': 1, 'h': 1},
  'animations': {
    'idle': {'sheet': 'pet.png', 'frameW': 1, 'frameH': 1, 'cols': 1,
      'box': {'x': 0, 'y': 0, 'w': 1, 'h': 1}, 'frames': [{'i': 0, 'ms': 100}]},
  },
  'states': {'idle': ['idle'], 'working': ['idle']},
});

void main() {
  test('production archive validator flattens one root and validates states', () {
    final result = preparePetArchive(zip({'folder/pack.json': manifest(), 'folder/pet.png': [1, 2, 3]}));
    expect(result.files['pet.png'], [1, 2, 3]);
    expect(result.manifest['id'], 'external');
    expect(PetPack.parse(result.manifest).animFor(PetStateName.working).sheet, 'pet.png');
  });

  test('production archive validator rejects traversal and missing sheets', () {
    expect(() => preparePetArchive(zip({'folder/pack.json': manifest(), 'folder/../pet.png': [1]})), throwsFormatException);
    expect(() => preparePetArchive(zip({'folder/pack.json': manifest()})), throwsFormatException);
    expect(() => preparePetArchive(zip({'/pack.json': manifest(), '/pet.png': [1]})), throwsFormatException);
  });
}