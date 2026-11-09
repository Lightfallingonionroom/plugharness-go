// SemVer 范围匹配的测试。重点不是把所有 semver 语法测全，而是把 DSH 生态里
// 真实出现过的写法钉住，尤其是 `0.2.2-rc.1` 这种 prerelease——本仓库的 runtime
// 固定版本就是这个，若预检对 prerelease 判断有误会直接把正常插件挡在门外。
import 'package:dsh_client/src/version_range.dart';
import 'package:test/test.dart';

void main() {
  group('exact versions', () {
    test('matches only the same version', () {
      expect(checkVersionRange('1.2.3', '1.2.3').verdict, RangeVerdict.satisfied);
      expect(checkVersionRange('1.2.3', '1.2.4').verdict, RangeVerdict.violates);
      expect(checkVersionRange('=1.2.3', '1.2.3').verdict, RangeVerdict.satisfied);
    });
  });

  group('caret ranges', () {
    test('^1.2.3 allows 1.2.3 up to but not including 2.0.0', () {
      expect(checkVersionRange('^1.2.3', '1.2.3').verdict, RangeVerdict.satisfied);
      expect(checkVersionRange('^1.2.3', '1.9.0').verdict, RangeVerdict.satisfied);
      expect(checkVersionRange('^1.2.3', '2.0.0').verdict, RangeVerdict.violates);
      expect(checkVersionRange('^1.2.3', '1.2.2').verdict, RangeVerdict.violates);
    });

    test('^0.2.2 stops at 0.3.0 — a 0.x minor bump is breaking', () {
      expect(checkVersionRange('^0.2.2', '0.2.2').verdict, RangeVerdict.satisfied);
      expect(checkVersionRange('^0.2.2', '0.2.9').verdict, RangeVerdict.satisfied);
      expect(checkVersionRange('^0.2.2', '0.3.0').verdict, RangeVerdict.violates);
    });

    test('^0.0.3 stops at 0.0.4', () {
      expect(checkVersionRange('^0.0.3', '0.0.3').verdict, RangeVerdict.satisfied);
      expect(checkVersionRange('^0.0.3', '0.0.4').verdict, RangeVerdict.violates);
    });
  });

  group('tilde ranges', () {
    test('~1.2.3 allows patch bumps only', () {
      expect(checkVersionRange('~1.2.3', '1.2.9').verdict, RangeVerdict.satisfied);
      expect(checkVersionRange('~1.2.3', '1.3.0').verdict, RangeVerdict.violates);
    });

    test('~1.2 pads to 1.2.0', () {
      expect(checkVersionRange('~1.2', '1.2.5').verdict, RangeVerdict.satisfied);
      expect(checkVersionRange('~1.2', '1.3.0').verdict, RangeVerdict.violates);
    });
  });

  group('conjunctions and alternatives', () {
    test('space-separated comparators are AND', () {
      expect(checkVersionRange('>=1.2.3 <2.0.0', '1.5.0').verdict, RangeVerdict.satisfied);
      expect(checkVersionRange('>=1.2.3 <2.0.0', '2.0.0').verdict, RangeVerdict.violates);
      expect(checkVersionRange('>=1.2.3 <2.0.0', '1.2.2').verdict, RangeVerdict.violates);
    });

    test('|| is OR', () {
      expect(checkVersionRange('^1.0.0 || ^2.0.0', '2.1.0').verdict, RangeVerdict.satisfied);
      expect(checkVersionRange('^1.0.0 || ^2.0.0', '3.0.0').verdict, RangeVerdict.violates);
    });
  });

  group('the version this repo actually pins', () {
    // runtime/build-runtime.sh: DSH_VERSION=0.2.2-rc.1
    const pinned = '0.2.2-rc.1';

    // Strict SemVer says 0.2.2-rc.1 < 0.2.2, so `^0.2.2` would refuse it and `>=0.2.2`
    // would too. This app ships exactly one runtime, so refusing the whole ecosystem over
    // a declaration nobody wrote with prereleases in mind is worse than saying "not
    // verified". Every range against a prerelease runtime is therefore `unknown`.
    test('any range against a prerelease runtime is unknown, never a refusal', () {
      for (final range in ['^0.2.2', '~0.2.2', '>=0.2.2', '^0.2.0', '0.2.2-rc.1']) {
        final r = checkVersionRange(range, pinned);
        expect(r.verdict, RangeVerdict.unknown, reason: '$range against $pinned');
        expect(r.reason, contains('prerelease'), reason: '$range against $pinned');
        expect(r.declared, range);
      }
    });

    test('a release runtime still gets a real verdict', () {
      expect(checkVersionRange('^0.2.2', '0.2.5').verdict, RangeVerdict.satisfied);
      expect(checkVersionRange('^0.2.2', '0.3.0').verdict, RangeVerdict.violates);
    });
  });

  group('unknowns stay unknown instead of guessing', () {
    test('no declaration is unknown, not satisfied', () {
      expect(checkVersionRange(null, '1.0.0').verdict, RangeVerdict.unknown);
      expect(checkVersionRange('', '1.0.0').verdict, RangeVerdict.unknown);
      expect(checkVersionRange('   ', '1.0.0').verdict, RangeVerdict.unknown);
    });

    test('unrecognised syntax is unknown and keeps the raw text', () {
      final r = checkVersionRange('workspace:*', '1.0.0');
      expect(r.verdict, RangeVerdict.unknown);
      expect(r.declared, 'workspace:*');
      expect(r.reason, isNotNull);
    });

    test('a non-semver runtime version is unknown, never a false violation', () {
      final r = checkVersionRange('^1.0.0', 'dev-build');
      expect(r.verdict, RangeVerdict.unknown);
      expect(r.reason, contains('not semver'));
    });

    test('a missing runtime version is unknown', () {
      expect(checkVersionRange('^1.0.0', null).verdict, RangeVerdict.unknown);
    });

    test('a partially unknown OR branch still reports unknown, not violation', () {
      // One branch unparsable, the other clearly not matching: we cannot prove
      // incompatibility, so we must not claim it.
      final r = checkVersionRange('workspace:* || ^9.0.0', '1.0.0');
      expect(r.verdict, RangeVerdict.unknown);
    });
  });

  group('wildcards and partials', () {
    test('* accepts anything', () {
      expect(checkVersionRange('*', '0.0.1').verdict, RangeVerdict.satisfied);
    });

    test('1.x matches the major only', () {
      expect(checkVersionRange('1.x', '1.9.9').verdict, RangeVerdict.satisfied);
      expect(checkVersionRange('1.x', '2.0.0').verdict, RangeVerdict.violates);
    });

    test('1.2.x matches major and minor', () {
      expect(checkVersionRange('1.2.x', '1.2.7').verdict, RangeVerdict.satisfied);
      expect(checkVersionRange('1.2.x', '1.3.0').verdict, RangeVerdict.violates);
    });
  });
}