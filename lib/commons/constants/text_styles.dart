import 'package:flutter/material.dart';

class TextStyles {
  static const String fontFamily = 'Inter';
  static const Color defaultTextColor = Colors.black;

  static TextStyle titleX({Color? color}) {
    return TextStyle(
      fontSize: 64,
      height: 1.25,
      fontWeight: FontWeight.w700,
      color: color ?? defaultTextColor,
      fontFamily: fontFamily,
    );
  }

  static TextStyle body3({Color? color}) {
    return TextStyle(
      fontSize: 14,
      height: 1.8,
      fontWeight: FontWeight.w500,
      color: color ?? defaultTextColor,
      fontFamily: fontFamily,
    );
  }

  static TextStyle title1({Color? color}) {
    return TextStyle(
      fontSize: 32,
      height: 1.06,
      fontWeight: FontWeight.w700,
      color: color ?? defaultTextColor,
      fontFamily: fontFamily,
    );
  }

  static TextStyle title2({Color? color}) {
    return TextStyle(
      fontSize: 24,
      height: 0.92,
      fontWeight: FontWeight.w600,
      color: color ?? defaultTextColor,
      fontFamily: fontFamily,
    );
  }

  static TextStyle title3({Color? color}) {
    return TextStyle(
      fontSize: 18,
      height: 1.22,
      fontWeight: FontWeight.w600,
      color: color ?? defaultTextColor,
      fontFamily: fontFamily,
    );
  }

  static TextStyle regular1({Color? color}) {
    return TextStyle(
      fontSize: 16,
      height: 1.19,
      fontWeight: FontWeight.w500,
      color: color ?? defaultTextColor,
      fontFamily: fontFamily,
    );
  }

  static TextStyle regular2({Color? color}) {
    return TextStyle(
      fontSize: 16,
      height: 1.19,
      fontWeight: FontWeight.w600,
      color: color ?? defaultTextColor,
      fontFamily: fontFamily,
    );
  }

  static TextStyle regular3({Color? color}) {
    return TextStyle(
      fontSize: 14,
      height: 1.28,
      fontWeight: FontWeight.w500,
      color: color ?? defaultTextColor,
      fontFamily: fontFamily,
    );
  }

  static TextStyle small({Color? color}) {
    return TextStyle(
      fontSize: 13,
      height: 1.23,
      fontWeight: FontWeight.w500,
      color: color ?? defaultTextColor,
      fontFamily: fontFamily,
    );
  }

  static TextStyle tiny({Color? color}) {
    return TextStyle(
      fontSize: 12,
      height: 1.0,
      fontWeight: FontWeight.w500,
      color: color ?? defaultTextColor,
      fontFamily: fontFamily,
    );
  }
}
