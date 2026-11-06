import 'package:dsh_app/state/feature_layout_state.dart';
import 'package:dsh_app/ui/features/feature_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

FeatureItem item(String id) => FeatureItem(
  id: id, title: id, summary: id, icon: Icons.add, native: (_) => const SizedBox(),
);

void main() {
  test('layout retains saved order and appends newly available features', () {
    final layout = const FeatureLayout(order: ['b', 'missing', 'a'], hidden: {'a'});
    expect(layout.resolve([item('a'), item('b'), item('c')]).map((e) => e.id), ['b', 'c']);
  });

  test('reorder and unhide preserve unrelated entries', () {
    const original = FeatureLayout(hidden: {'c'});
    final visible = [item('a'), item('b')];
    final moved = original.reorder(0, 1, visible);
    expect(moved.order, ['b', 'a']);
    expect(moved.hidden, {'c'});
    expect(moved.resolve([item('a'), item('b'), item('c')]).map((e) => e.id), ['b', 'a']);
  });
}