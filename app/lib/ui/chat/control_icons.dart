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

/// 官方终端图标，来自 ds_terminal_regular_24.xml。
/// 用于「查看工作进展」按钮的**点按**动作（打开终端页）。
class ChatGptTerminalPath {
  const ChatGptTerminalPath._();

  /// 提示符 `>`。
  static const prompt =
      'M7.29297 9.29297C7.6835 8.90251 8.31653 8.90247 8.70704 9.29297L10.707 11.293C11.0975 11.6835 11.0975 12.3165 10.707 12.707L8.70704 14.707C8.31652 15.0976 7.6835 15.0975 7.29297 14.707C6.90245 14.3165 6.90245 13.6835 7.29297 13.293L8.58594 12L7.29297 10.707C6.90245 10.3165 6.90245 9.6835 7.29297 9.29297Z';

  /// 光标横杠。
  static const cursor =
      'M16 13C16.5523 13 17 13.4477 17 14C17 14.5523 16.5523 15 16 15H13C12.4477 15 12 14.5523 12 14C12 13.4477 12.4477 13 13 13H16Z';

  /// 窗口外框（even-odd 挖空）。
  static const window =
      'M15.5195 3C16.2871 3 16.9234 2.99878 17.4404 3.04102C17.9691 3.08421 18.461 3.1778 18.9248 3.41407C19.6398 3.77838 20.2216 4.36019 20.5859 5.0752C20.8222 5.53905 20.9158 6.03095 20.959 6.55957C21.0012 7.07663 21 7.71294 21 8.48047V15.5195C21 16.2871 21.0012 16.9234 20.959 17.4404C20.9158 17.9691 20.8222 18.461 20.5859 18.9248C20.2216 19.6398 19.6398 20.2216 18.9248 20.5859C18.461 20.8222 17.9691 20.9158 17.4404 20.959C16.9234 21.0012 16.2871 21 15.5195 21H8.48047C7.71294 21 7.07663 21.0012 6.55957 20.959C6.03095 20.9158 5.53905 20.8222 5.0752 20.5859C4.36019 20.2216 3.77838 19.6398 3.41407 18.9248C3.1778 18.461 3.08421 17.9691 3.04102 17.4404C2.99878 16.9234 3 16.2871 3 15.5195V8.48047C3 7.71294 2.99878 7.07663 3.04102 6.55957C3.08421 6.03095 3.1778 5.53905 3.41407 5.0752C3.77838 4.36018 4.36018 3.77838 5.0752 3.41407C5.53905 3.1778 6.03095 3.08421 6.55957 3.04102C7.07663 2.99878 7.71294 3 8.48047 3H15.5195ZM8.48047 5C7.68005 5 7.13937 5.00113 6.72266 5.03516C6.3176 5.06825 6.11743 5.1275 5.98243 5.19629C5.64402 5.36882 5.36882 5.64402 5.19629 5.98243C5.1275 6.11743 5.06825 6.3176 5.03516 6.72266C5.00113 7.13937 5 7.68005 5 8.48047V15.5195C5 16.32 5.00113 16.8606 5.03516 17.2773C5.06825 17.6824 5.1275 17.8826 5.19629 18.0176C5.36882 18.356 5.64402 18.6312 5.98243 18.8037C6.11743 18.8725 6.3176 18.9318 6.72266 18.9648C7.13937 18.9989 7.68005 19 8.48047 19H15.5195C16.32 19 16.8606 18.9989 17.2773 18.9648C17.6824 18.9318 17.8826 18.8725 18.0176 18.8037C18.356 18.6312 18.6312 18.356 18.8037 18.0176C18.8725 17.8826 18.9318 17.6824 18.9648 17.2773C18.9989 16.8606 19 16.32 19 15.5195V8.48047C19 7.68005 18.9989 7.13937 18.9648 6.72266C18.9318 6.3176 18.8725 6.11743 18.8037 5.98243C18.6312 5.64402 18.356 5.36882 18.0176 5.19629C17.8826 5.1275 17.6824 5.06825 17.2773 5.03516C16.8606 5.00113 16.32 5 15.5195 5H8.48047Z';

  static const all = <String>[prompt, cursor, window];
}

/// 官方文件夹图标，来自 ds_folder_regular_24.xml。
/// 用于「查看工作进展」按钮的**长按**动作（打开文件页）。
class ChatGptFolderPath {
  const ChatGptFolderPath._();

  static const body =
      'M8.33984 3C9.14269 3.00008 9.92488 3.25442 10.5742 3.72656L11.8516 4.65527C12.1591 4.87895 12.5299 4.99992 12.9102 5H17.9502C20.0487 5.00011 21.7499 6.70128 21.75 8.7998V17.2002C21.7499 19.2987 20.0487 20.9999 17.9502 21H6.0498C3.95128 20.9999 2.25011 19.2987 2.25 17.2002V6.7998C2.25011 4.70128 3.95128 3.00011 6.0498 3H8.33984ZM4.25 12V17.2002C4.25011 18.1942 5.05585 18.9999 6.0498 19H17.9502C18.9442 18.9999 19.7499 18.1942 19.75 17.2002V12H4.25ZM6.0498 5C5.05585 5.00011 4.25011 5.80585 4.25 6.7998V10H19.75V8.7998C19.7499 7.80585 18.9442 7.00011 17.9502 7H12.9102C12.1073 6.99992 11.3251 6.74558 10.6758 6.27344L9.39844 5.34473C9.09088 5.12105 8.72013 5.00008 8.33984 5H6.0498Z';

  static const all = <String>[body];
}

/// 官方「闹钟 + 打勾」图标，来自 ds_alarm_clock_checkmark_regular_24.xml。
/// 用于侧边栏的「自动化任务」入口——到点自动跑，正是这个语义。
class ChatGptScheduledTaskPath {
  const ChatGptScheduledTaskPath._();

  /// 打勾。
  static const check =
      'M14.5634 8.96282C14.8709 8.50431 15.4924 8.38117 15.9511 8.6884C16.4095 8.996 16.5319 9.61748 16.2245 10.0761L12.0693 16.2753C11.6209 16.944 10.6665 17.02 10.1171 16.4316L7.87492 14.0292C7.49838 13.6255 7.52036 12.9929 7.92375 12.6161C8.32759 12.2395 8.96111 12.2612 9.33782 12.665L10.9335 14.3759L14.5634 8.96282Z';

  /// 钟面（even-odd 挖空）。
  static const face =
      'M11.9999 2.99992C17.2466 2.99992 21.4999 7.25322 21.4999 12.4999C21.4999 15.0492 20.4937 17.362 18.8593 19.0683L20.7685 21.3593C21.1219 21.7835 21.0647 22.4149 20.6405 22.7685C20.2163 23.122 19.585 23.0646 19.2314 22.6405L17.3329 20.3622C15.8125 21.3956 13.9769 21.9999 11.9999 21.9999C10.0227 21.9999 8.18654 21.3958 6.66594 20.3622L4.76848 22.6405C4.41488 23.0646 3.78351 23.122 3.3593 22.7685C2.93517 22.4149 2.87794 21.7835 3.23137 21.3593L5.13957 19.0683C3.50549 17.362 2.49994 15.049 2.49992 12.4999C2.49992 7.25322 6.75322 2.99992 11.9999 2.99992ZM11.9999 4.99992C7.85779 4.99992 4.49992 8.35779 4.49992 12.4999C4.49997 16.642 7.85781 19.9999 11.9999 19.9999C16.142 19.9999 19.4999 16.642 19.4999 12.4999C19.4999 8.35779 16.1421 4.99992 11.9999 4.99992Z';

  /// 左铃。
  static const bellLeft =
      'M5.29289 1.29289C5.68342 0.902369 6.31643 0.902369 6.70696 1.29289C7.0974 1.68342 7.09746 2.31646 6.70696 2.70696L2.70696 6.70696C2.31646 7.09746 1.68342 7.0974 1.29289 6.70696C0.902369 6.31643 0.902369 5.68342 1.29289 5.29289L5.29289 1.29289Z';

  /// 右铃。
  static const bellRight =
      'M17.2929 1.29289C17.6834 0.902369 18.3164 0.902369 18.707 1.29289L22.707 5.29289C23.0975 5.68342 23.0975 6.31643 22.707 6.70696C22.3164 7.0974 21.6834 7.09746 21.2929 6.70696L17.2929 2.70696C16.9024 2.31646 16.9024 1.68342 17.2929 1.29289Z';

  static const all = <String>[check, face, bellLeft, bellRight];
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

/// 官方终端图标。「查看工作进展」按钮**点按**打开它。
class ChatGptTerminalIcon extends StatelessWidget {
  const ChatGptTerminalIcon({super.key, this.size = 22, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? IconTheme.of(context).color;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _VectorGlyphPainter(ChatGptTerminalPath.all, tint)),
    );
  }
}

/// 官方文件夹图标。「查看工作进展」按钮**长按**打开它。
class ChatGptFolderIcon extends StatelessWidget {
  const ChatGptFolderIcon({super.key, this.size = 22, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? IconTheme.of(context).color;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _VectorGlyphPainter(ChatGptFolderPath.all, tint)),
    );
  }
}

/// 官方「闹钟 + 打勾」图标。侧边栏「自动化任务」入口用。
class ChatGptScheduledTaskIcon extends StatelessWidget {
  const ChatGptScheduledTaskIcon({super.key, this.size = 22, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? IconTheme.of(context).color;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _VectorGlyphPainter(ChatGptScheduledTaskPath.all, tint)),
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