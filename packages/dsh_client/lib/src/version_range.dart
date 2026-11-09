// SemVer 范围匹配：判断插件的 `engines.dsh` / `engines.node` 是否接受本机运行时。
//
// 只实现 DSH 生态实际用到的语法，遇到不认识的写法一律返回
// [RangeVerdict.unknown] 而不是猜：
//
//   *                任意版本
//   1.2.3            精确
//   =1.2.3           同上
//   ^1.2.3           >=1.2.3 <2.0.0（0.x 时上界收窄到 <0.(x+1).0）
//   ~1.2.3           >=1.2.3 <1.3.0
//   >=1.2.3 <2.0.0   空格分隔即「且」
//   >=1.2.3 || ^2.0  双竖线即「或」
//
// `compareSemver` 和 `isExactSemver` 在 `plugins_api.dart` 里已有，这里复用它们，
// 不再造一套版本解析——否则 prerelease 的先后顺序会出现两个实现。
import 'plugins_api.dart' show compareSemver, isExactSemver;

/// 一次范围检查的结论。
enum RangeVerdict {
  /// 明确满足。
  satisfied,

  /// 明确不满足：可以拒绝安装，并把冲突的原始写法报给用户。
  violates,

  /// 没有声明，或写法不认识：允许继续，界面提示「未验证兼容性」。
  unknown,
}

/// 一次检查的结果，带着原样保留的声明文本，界面要展示它而不是自己的解释。
class RangeCheck {
  const RangeCheck(this.verdict, this.declared, {this.reason});

  final RangeVerdict verdict;

  /// 插件原样声明的范围，例如 `^0.2.0`。没有声明时为 null。
  final String? declared;

  /// 为什么判不了（仅 [RangeVerdict.unknown] 时非空），用于诊断。
  final String? reason;

  static const none = RangeCheck(RangeVerdict.unknown, null);

  static RangeCheck ok(String declared) => RangeCheck(RangeVerdict.satisfied, declared);

  static RangeCheck bad(String declared) => RangeCheck(RangeVerdict.violates, declared);

  static RangeCheck unknown(String declared, String reason) => RangeCheck(RangeVerdict.unknown, declared, reason: reason);
}

/// 判断 [version]（本机运行时版本）是否落在 [range] 里。
///
/// [version] 本身不是合法 semver 时返回 unknown：一个 `0.2.2-rc.1` 之外的自定义
/// 版本字符串（开发构建、发行版后缀）不该让预检谎报不兼容。
RangeCheck checkVersionRange(String? range, String? version) {
  if (range == null || range.trim().isEmpty) return RangeCheck.none;
  final declared = range.trim();
  if (version == null || version.trim().isEmpty) {
    return RangeCheck.unknown(declared, 'runtime version unknown');
  }
  final v = version.trim();
  if (!isExactSemver(v)) return RangeCheck.unknown(declared, 'runtime version is not semver: $v');

  // A prerelease runtime is never *refused* by range matching.
  //
  // Strict SemVer says `0.2.2-rc.1 < 0.2.2`, so `^0.2.2` does not admit it. That rule is
  // right for package managers that opt in to prereleases explicitly, but this app ships
  // exactly one runtime (build-runtime.sh: `0.2.2-rc.1`) and a plugin author writing
  // `^0.2.0` means "the 0.2 line", not "and please exclude the rc we all run".
  // Pretending to know better would block working plugins, so the verdict here is
  // `unknown`: the install proceeds and the UI says the compatibility was not verified.
  if (_prereleaseOf(v) != null) {
    return RangeCheck.unknown(declared, 'runtime version is a prerelease: $v');
  }

  // `||` binds loosest: any one alternative satisfying is enough.
  final alternatives = declared.split('||');
  var sawUnknown = false;
  String? unknownReason;
  for (final alternative in alternatives) {
    final one = _checkConjunction(alternative.trim(), v);
    switch (one.verdict) {
      case RangeVerdict.satisfied:
        return RangeCheck.ok(declared);
      case RangeVerdict.unknown:
        sawUnknown = true;
        unknownReason ??= one.reason;
      case RangeVerdict.violates:
        break;
    }
  }
  if (sawUnknown) return RangeCheck.unknown(declared, unknownReason ?? 'unverifiable range');
  return RangeCheck.bad(declared);
}

/// One `>=1.2.3 <2.0.0` alternative: every space-separated comparator must hold.
RangeCheck _checkConjunction(String alternative, String version) {
  if (alternative.isEmpty || alternative == '*' || alternative == 'x' || alternative == 'X') {
    return RangeCheck.ok(alternative.isEmpty ? '*' : alternative);
  }
  // A bare version with no comparator and no wildcard is an exact match.
  final parts = alternative.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  for (final part in parts) {
    final one = _checkComparator(part, version);
    switch (one.verdict) {
      case RangeVerdict.satisfied:
        continue;
      case RangeVerdict.violates:
        return one;
      case RangeVerdict.unknown:
        return one;
    }
  }
  return RangeCheck.ok(alternative);
}

/// One comparator: `^1.2.3`, `~1.2`, `>=1.2.3`, `1.2.3`, `1.x`, ...
RangeCheck _checkComparator(String raw, String version) {
  final text = raw.trim();
  if (text.isEmpty) return RangeCheck.ok(raw);

  // `1.x` / `1.2.x` / `1.*`: a partial version. Only the named parts must match.
  if (RegExp(r'^[vV]?\d+(?:\.(?:\d+|x|X|\*)){0,2}$').hasMatch(text) && !isExactSemver(text)) {
    final want = text.replaceFirst(RegExp(r'^[vV]'), '');
    // Treat a partial as a range: pad the missing parts with 0 for a lower bound and
    // compare only the parts the author actually wrote.
    final wantParts = want.split('.');
    final haveParts = version.split('.').take(wantParts.length).toList();
    for (var i = 0; i < wantParts.length && i < haveParts.length; i++) {
      final w = wantParts[i];
      if (w == 'x' || w == 'X' || w == '*') continue;
      final h = haveParts[i].split('-').first.split('+').first;
      if (w != h) return RangeCheck.bad(raw);
    }
    return RangeCheck.ok(raw);
  }

  // Comparators, longest operator first so `>=` is not read as `>` followed by `=`.
  for (final op in const ['>=', '<=', '>', '<', '=', '^', '~']) {
    if (!text.startsWith(op)) continue;
    final body = text.substring(op.length).trim();
    final base = _baseVersion(body);
    if (base == null) return RangeCheck.unknown(raw, 'unparsable version in "$raw"');
    final cmp = compareSemver(version, base);
    final ok = switch (op) {
      '>=' => cmp >= 0,
      '<=' => cmp <= 0,
      '>' => cmp > 0,
      '<' => cmp < 0,
      '=' => cmp == 0,
      '^' => _caretSatisfied(version, base),
      '~' => _tildeSatisfied(version, base),
      _ => false,
    };
    return ok ? RangeCheck.ok(raw) : RangeCheck.bad(raw);
  }

  // A bare exact version.
  if (isExactSemver(text)) {
    return compareSemver(version, text) == 0 ? RangeCheck.ok(raw) : RangeCheck.bad(raw);
  }
  return RangeCheck.unknown(raw, 'unrecognised range syntax "$raw"');
}

/// `^1.2.3` → `>=1.2.3 <2.0.0`, except for `0.x` where the next release is breaking too.
bool _caretSatisfied(String version, String base) {
  if (compareSemver(version, base) < 0) return false;
  final m = RegExp(r'^(\d+)\.(\d+)\.(\d+)').firstMatch(base);
  if (m == null) return false;
  final major = BigInt.parse(m.group(1)!);
  final minor = BigInt.parse(m.group(2)!);
  final upper = major > BigInt.zero
      ? '${major + BigInt.one}.0.0'
      : minor > BigInt.zero
          ? '0.${minor + BigInt.one}.0'
          : '0.0.${BigInt.parse(m.group(3)!) + BigInt.one}';
  return compareSemver(version, upper) < 0;
}

/// `~1.2.3` → `>=1.2.3 <1.3.0`; `~1.2` → `>=1.2.0 <1.3.0`; `~1` → `>=1.0.0 <2.0.0`.
bool _tildeSatisfied(String version, String base) {
  if (compareSemver(version, base) < 0) return false;
  final m = RegExp(r'^(\d+)\.(\d+)\.(\d+)').firstMatch(base);
  if (m == null) return false;
  final major = BigInt.parse(m.group(1)!);
  final minor = BigInt.parse(m.group(2)!);
  final upper = '$major.${minor + BigInt.one}.0';
  return compareSemver(version, upper) < 0;
}

/// The prerelease part of [version], or null when it is a plain release.
String? _prereleaseOf(String version) {
  final plus = version.indexOf('+');
  final core = plus < 0 ? version : version.substring(0, plus);
  final dash = core.indexOf('-');
  return dash < 0 ? null : core.substring(dash + 1);
}

/// Pad `1.2` to `1.2.0` so `compareSemver` (which needs three parts) can read it.
String? _baseVersion(String body) {
  if (isExactSemver(body)) return body;
  final m = RegExp(r'^[vV]?(\d+)(?:\.(\d+))?(?:\.(\d+))?').firstMatch(body);
  if (m == null) return null;
  final major = m.group(1)!;
  final minor = m.group(2) ?? '0';
  final patch = m.group(3) ?? '0';
  final candidate = '$major.$minor.$patch';
  return isExactSemver(candidate) ? candidate : null;
}