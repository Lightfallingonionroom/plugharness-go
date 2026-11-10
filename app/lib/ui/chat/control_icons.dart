// 输入条两个控制器按钮的图标。
//
// 两个都是矢量绘制，不是位图：它们要随主题变色、要随档位旋转，位图做不到。
//
//   ChatGptStorageBadgeGearIcon  输入条左侧「控制面板」按钮。
//      来自 ChatGPT 官方包 com.openai.chatgpt 1.2026.300 的设计系统：
//      assets/composeResources/com.openai.kmp.platform.design.resources/
//        drawable/ds_storage_badge_gear_regular_24.xml
//      （设置里「历史记录与资料」那一项用的就是它）
//
//   ChatGptGearIcon              底栏右下角设置入口。
//      同上来源，ds_gear_regular_24.xml
//
//   ReasoningGaugeIcon           输入条右侧推理强度。
//      按用户提供的 SVG 复刻（270° 弧 + 指针 + 中心点），不是官方图标。

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

/// 从 ChatGPT 设计系统搬来的原始 pathData。
///
/// 24×24 视口，`evenOdd` 填充（内孔是真的洞，不是叠色遮出来的）。两段 path
/// 一段都不能省：齿轮在上、圆柱在下，合成你截图里那个「两半圆柱 + 齿轮」。
class ChatGptStorageBadgeGearPath {
  const ChatGptStorageBadgeGearPath._();

  /// 齿轮外轮廓 + 中心孔。
  static const gear =
      'M19.2988 13.5C19.5827 13.5002 19.8418 13.6611 19.9688 13.915L20.5039 14.9834L21.6963 14.9121C21.9798 14.8951 22.2485 15.0393 22.3906 15.2852L22.9277 16.2148C23.0695 16.4608 23.0598 16.766 22.9033 17.0029L22.2451 18L22.9033 18.9971C23.0598 19.234 23.0696 19.5392 22.9277 19.7852L22.3906 20.7148C22.2485 20.9607 21.9798 21.1049 21.6963 21.0879L20.5039 21.0166L19.9688 22.085C19.8418 22.3389 19.5827 22.4998 19.2988 22.5H18.2256C17.9415 22.5 17.6817 22.3391 17.5547 22.085L17.0205 21.0166L15.8271 21.0879C15.5437 21.1048 15.2748 20.9607 15.1328 20.7148L14.5967 19.7852C14.4547 19.5392 14.4636 19.2341 14.6201 18.9971L15.2783 18L14.6201 17.0029C14.4636 16.7659 14.4547 16.4608 14.5967 16.2148L15.1328 15.2852C15.2748 15.0393 15.5437 14.8952 15.8271 14.9121L17.0205 14.9834L17.5547 13.915C17.6817 13.661 17.9415 13.5 18.2256 13.5H19.2988ZM18.7617 16.5C17.9334 16.5001 17.2617 17.1716 17.2617 18C17.2617 18.8284 17.9334 19.4999 18.7617 19.5C19.5901 19.5 20.2617 18.8284 20.2617 18C20.2617 17.1716 19.5901 16.5 18.7617 16.5Z';

  /// 圆柱（上下两半，中间留缝）。
  static const cylinder =
      'M12 2.00781C14.0396 2.00781 15.9207 2.36721 17.3262 2.93848C18.0253 3.22268 18.6529 3.57782 19.123 4.00586C19.583 4.42463 20 5.01739 20 5.75781V9.6123C20 10.1646 19.5523 10.6123 19 10.6123C18.4477 10.6123 18 10.1646 18 9.6123V8.2666C17.7854 8.37762 17.5601 8.48208 17.3262 8.57715C15.9207 9.14842 14.0396 9.50781 12 9.50781C9.96043 9.50781 8.07932 9.14842 6.67383 8.57715C6.43993 8.48208 6.21461 8.37762 6 8.2666V12.1143C6.00429 12.1298 6.03591 12.2265 6.22363 12.3975C6.46187 12.6144 6.85931 12.8611 7.42676 13.0918C8.55475 13.5503 10.1737 13.875 12 13.875C12.5523 13.875 13 14.3227 13 14.875C13 15.4273 12.5523 15.875 12 15.875C9.96043 15.875 8.07932 15.5156 6.67383 14.9443C6.43989 14.8492 6.21468 14.7448 6 14.6338V18.2432C6.00417 18.2587 6.03577 18.3553 6.22363 18.5264C6.46187 18.7433 6.85931 18.99 7.42676 19.2207C8.55475 19.6792 10.1737 20.0039 12 20.0039C12.5523 20.0039 13 20.4516 13 21.0039C13 21.5562 12.5523 22.0039 12 22.0039C9.96043 22.0039 8.07932 21.6445 6.67383 21.0732C5.97465 20.789 5.34712 20.4339 4.87695 20.0059C4.41704 19.5871 4 18.9943 4 18.2539V5.75781C4 5.01739 4.41704 4.42463 4.87695 4.00586C5.34712 3.57782 5.97465 3.22268 6.67383 2.93848C8.07932 2.36721 9.96043 2.00781 12 2.00781ZM12 4.00781C10.1737 4.00781 8.55475 4.33253 7.42676 4.79102C6.85931 5.02167 6.46187 5.26842 6.22363 5.48535C6.06143 5.63305 6.01603 5.72535 6.00391 5.75781C6.01603 5.79028 6.06143 5.88258 6.22363 6.03027C6.46187 6.2472 6.85931 6.49395 7.42676 6.72461C8.55475 7.1831 10.1737 7.50781 12 7.50781C13.8263 7.50781 15.4453 7.1831 16.5732 6.72461C17.1407 6.49395 17.5381 6.2472 17.7764 6.03027C17.938 5.88306 17.9828 5.79056 17.9951 5.75781C17.9828 5.72506 17.938 5.63256 17.7764 5.48535C17.5381 5.26842 17.1407 5.02167 16.5732 4.79102C15.4453 4.33253 13.8263 4.00781 12 4.00781Z';

  static const all = <String>[gear, cylinder];
}

/// 官方齿轮（设置入口），来自 ds_gear_regular_24.xml。
class ChatGptGearPath {
  const ChatGptGearPath._();

  static const ring =
      'M11.9995 7.7002C14.3741 7.7002 16.299 9.62538 16.2993 12C16.2993 14.3748 14.3743 16.2998 11.9995 16.2998C9.62491 16.2995 7.69965 14.3746 7.69965 12C7.69988 9.62558 9.62505 7.70053 11.9995 7.7002ZM11.9995 9.7002C10.7296 9.70053 9.69988 10.7302 9.69965 12C9.69965 13.2701 10.7295 14.2995 11.9995 14.2998C13.2697 14.2998 14.2993 13.2703 14.2993 12C14.299 10.73 13.2696 9.7002 11.9995 9.7002Z';

  static const body =
      'M12.8969 1.54395C13.7016 1.54397 14.4463 1.9736 14.8481 2.67286C15.17 3.23327 15.6493 4.06733 16.0356 4.73829C16.0794 4.81422 16.1607 4.86219 16.2504 4.86231H18.6362C19.4397 4.86252 20.1826 5.29049 20.5844 5.98634L21.4702 7.52052C21.869 8.21166 21.872 9.06296 21.478 9.75684L20.2026 12L21.477 14.2441C21.8713 14.9382 21.8683 15.7892 21.4692 16.4805L20.5844 18.0137C20.1825 18.7098 19.439 19.1387 18.6352 19.1387H16.2504C16.1607 19.1388 16.0794 19.1868 16.0356 19.2627C15.6493 19.9336 15.17 20.7678 14.8481 21.3281C14.4463 22.0273 13.7015 22.457 12.8969 22.457C12.2636 22.4571 11.7554 22.4571 11.103 22.457C10.2984 22.457 9.55362 22.0274 9.1518 21.3281C8.8299 20.7677 8.35062 19.9337 7.9643 19.2627C7.92048 19.1867 7.83922 19.1388 7.74945 19.1387H5.36469C4.56101 19.1386 3.8174 18.7106 3.41547 18.0147L2.52973 16.4805C2.13092 15.7894 2.12795 14.938 2.52191 14.2441L3.79828 12.001L2.52289 9.75684C2.12863 9.06282 2.13166 8.21179 2.5307 7.52052L3.41547 5.98634C3.81741 5.2903 4.56092 4.86135 5.36469 4.86134H7.74945C7.83932 4.86129 7.92048 4.81342 7.9643 4.73731C8.35064 4.06628 8.83095 3.23315 9.15277 2.67286C9.55455 1.97364 10.2984 1.54408 11.103 1.54395C11.7553 1.54394 12.2636 1.54394 12.8969 1.54395ZM11.1039 3.54395C11.0134 3.54395 10.9294 3.59207 10.8852 3.66895C10.5632 4.22947 10.0845 5.06446 9.69769 5.73634C9.29587 6.434 8.5525 6.86224 7.74945 6.86231H5.36469C5.27537 6.86231 5.19255 6.90996 5.14789 6.98731L4.26312 8.51954C4.21881 8.59629 4.21845 8.69148 4.26215 8.76856L5.81586 11.5049C5.90153 11.6558 5.94761 11.8265 5.9477 12C5.9477 12.1301 5.92221 12.2592 5.87348 12.3789L5.81586 12.4961L4.26215 15.2324C4.21863 15.3093 4.21811 15.4039 4.26215 15.4805L5.14789 17.0147C5.19261 17.0917 5.27554 17.1397 5.36469 17.1397H7.74945C8.55263 17.1397 9.29591 17.5678 9.69769 18.2656C10.0845 18.9375 10.5643 19.7717 10.8862 20.332C10.9303 20.4087 11.0126 20.4569 11.103 20.457C11.7554 20.4571 12.2636 20.4571 12.8969 20.457C12.9874 20.457 13.0705 20.409 13.1147 20.332C13.4366 19.7715 13.9153 18.9366 14.3022 18.2647C14.704 17.5669 15.4474 17.1388 16.2504 17.1387H18.6352C18.7245 17.1387 18.8073 17.091 18.852 17.0137L19.7377 15.4805C19.7818 15.4038 19.7813 15.3093 19.7377 15.2324L18.184 12.4961C18.0983 12.3451 18.0532 12.1738 18.0532 12C18.0532 11.8266 18.0984 11.6558 18.184 11.5049L19.7387 8.76856C19.7822 8.69167 19.7818 8.59709 19.7377 8.52052L18.852 6.98634C18.8073 6.90921 18.7244 6.86134 18.6352 6.86134H16.2504C15.4473 6.86123 14.704 6.43317 14.3022 5.73536C13.9153 5.06345 13.4356 4.22933 13.1137 3.66895C13.0695 3.59219 12.9873 3.54402 12.8969 3.54395C12.2639 3.54394 11.7559 3.54394 11.1039 3.54395Z';

  static const all = <String>[ring, body];
}

/// 解析 Android vector 的 pathData 成 [Path]。
///
/// 官方这两个图标只用 M/L/C/H/V/Z 与它们的小写相对形式，所以解析器只覆盖
/// 这些；真出现别的指令会抛异常，而不是画出一个不对的图形（静默画错比报错
/// 更难查）。
Path parseVectorPath(String data) {
  final path = Path();
  final tokens = _tokenize(data);
  var i = 0;
  var cx = 0.0, cy = 0.0;
  var startX = 0.0, startY = 0.0;

  double number() => double.parse(tokens[i++]);

  while (i < tokens.length) {
    final cmd = tokens[i++];
    switch (cmd) {
      case 'M':
        cx = number();
        cy = number();
        startX = cx;
        startY = cy;
        path.moveTo(cx, cy);
      case 'm':
        cx += number();
        cy += number();
        startX = cx;
        startY = cy;
        path.moveTo(cx, cy);
      case 'L':
        cx = number();
        cy = number();
        path.lineTo(cx, cy);
      case 'l':
        cx += number();
        cy += number();
        path.lineTo(cx, cy);
      case 'H':
        cx = number();
        path.lineTo(cx, cy);
      case 'h':
        cx += number();
        path.lineTo(cx, cy);
      case 'V':
        cy = number();
        path.lineTo(cx, cy);
      case 'v':
        cy += number();
        path.lineTo(cx, cy);
      case 'C':
        final x1 = number(), y1 = number();
        final x2 = number(), y2 = number();
        cx = number();
        cy = number();
        path.cubicTo(x1, y1, x2, y2, cx, cy);
      case 'c':
        final x1 = cx + number(), y1 = cy + number();
        final x2 = cx + number(), y2 = cy + number();
        cx += number();
        cy += number();
        path.cubicTo(x1, y1, x2, y2, cx, cy);
      case 'Z':
      case 'z':
        path.close();
        cx = startX;
        cy = startY;
      default:
        throw ArgumentError('vector pathData: unsupported command "$cmd"');
    }
  }
  return path;
}

final _vectorToken = RegExp(r'[MLHVCZmlhvcz]|[-+]?(?:\d*\.\d+|\d+)(?:[eE][-+]?\d+)?');

List<String> _tokenize(String data) =>
    [for (final m in _vectorToken.allMatches(data)) m.group(0)!];

/// 官方「存储 + 齿轮」图标，输入条左侧控制面板按钮用。
class ChatGptStorageBadgeGearIcon extends StatelessWidget {
  const ChatGptStorageBadgeGearIcon({super.key, this.size = 20, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? IconTheme.of(context).color;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _VectorGlyphPainter(ChatGptStorageBadgeGearPath.all, tint),
      ),
    );
  }
}

/// 官方齿轮图标，底栏右下角设置入口用。
class ChatGptGearIcon extends StatelessWidget {
  const ChatGptGearIcon({super.key, this.size = 22, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? IconTheme.of(context).color;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _VectorGlyphPainter(ChatGptGearPath.all, tint)),
    );
  }
}

class _VectorGlyphPainter extends CustomPainter {
  _VectorGlyphPainter(this.paths, this.color);

  final List<String> paths;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // 24×24 视口等比缩放到目标尺寸；不分别拉伸，否则圆弧会变成椭圆。
    final scale = size.shortestSide / 24;
    canvas.save();
    canvas.scale(scale, scale);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    for (final data in paths) {
      // evenOdd：官方图标的内孔（齿轮中心、圆柱分层）靠填充规则挖空。
      canvas.drawPath(parseVectorPath(data), paint..fillType = PathFillType.evenOdd);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_VectorGlyphPainter old) =>
      old.color != color || !listEquals(old.paths, paths);
}

// ---------------------------------------------------------------------------
// 推理强度仪表：按用户提供的 SVG 复刻。
//
// SVG 原文（100×100 视口）：
//   半径 38、线宽 8、弧占 0.75 个圆周（270°）
//   圆环 rotate(135 50 50)，起点落在 7 点半方向
//   指针角度 = 225° + 270° × progress
//   指针线从圆心指向 (50,22)，中心圆点半径 5.5
// ---------------------------------------------------------------------------

class ReasoningGaugeIcon extends StatelessWidget {
  const ReasoningGaugeIcon({
    super.key,
    this.size = 24,
    this.progress = 0,
    this.color,
    this.trackColor,
  });

  final double size;

  /// 0 = 关闭，1 = 最高档。档位 i 对应 i / (n - 1)。
  final double progress;

  final Color? color;
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _ReasoningGaugePainter(
          progress: progress,
          active: color ?? scheme.primary,
          track: trackColor ?? scheme.onSurface.withValues(alpha: 0.16),
        ),
      ),
    );
  }
}

class _ReasoningGaugePainter extends CustomPainter {
  _ReasoningGaugePainter({required this.progress, required this.active, required this.track});

  final double progress;
  final Color active;
  final Color track;

  static const _radius = 38.0;
  static const _stroke = 8.0;
  static const _arc = 0.75; // 270°
  static const _twoPi = 6.283185307179586;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 100;
    final p = progress.clamp(0.0, 1.0);

    canvas.save();
    canvas.scale(scale, scale);
    canvas.translate(50, 50);

    // 底弧：整体先转 135°，让 270° 的弧从 7 点半开始、到 4 点半结束。
    canvas.save();
    canvas.rotate(135 * math.pi / 180);
    final bounds = Rect.fromCircle(center: Offset.zero, radius: _radius);
    canvas.drawArc(
      bounds,
      0,
      _arc * _twoPi,
      false,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeCap = StrokeCap.round,
    );
    if (p > 0) {
      canvas.drawArc(
        bounds,
        0,
        p * _arc * _twoPi,
        false,
        Paint()
          ..color = active
          ..style = PaintingStyle.stroke
          ..strokeWidth = _stroke
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.restore();

    // 指针与中心点：角度 = 225° + 270° × progress。
    final angle = (225 + 270 * p) * math.pi / 180;
    final length = _radius - 8;
    canvas.drawLine(
      Offset.zero,
      Offset(length * math.cos(angle), length * math.sin(angle)),
      Paint()
        ..color = active
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(Offset.zero, 4.5, Paint()..color = active);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_ReasoningGaugePainter old) =>
      old.progress != progress || old.active != active || old.track != track;
}