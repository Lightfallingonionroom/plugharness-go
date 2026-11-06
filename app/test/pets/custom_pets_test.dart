import 'package:dsh_app/pets/custom_pets.dart';
import 'package:dsh_app/pets/pet_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('single-image custom pack is valid for every runtime state', () {
    final pack = singleImagePack(id: 'custom-test', name: 'Mine', width: 320, height: 180);
    expect(pack.id, 'custom-test');
    expect(pack.name, 'Mine');
    expect(pack.pixelArt, isFalse);
    expect(pack.animations.length, 1);
    expect(pack.animFor(PetStateName.working).sheet, 'pet.png');
    expect(pack.animFor(PetStateName.sleeping).frameWidth, 320);
    expect(pack.contentBox.width, 320);
  });
}