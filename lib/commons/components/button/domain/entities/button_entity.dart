import 'package:flutter/material.dart';

class ButtonEntity {
  final String label;
  final Color? labelColor;
  final String? iconPath;
  final bool isLeadingIcon;
  final bool isEnabled;
  final bool isSolid;
  final bool hasBorder;
  final Color? borderColor;
  final Color? iconColor;
  final bool? isCircle;

  
  ButtonEntity({
    required this.label,
    this.labelColor,
    this.iconPath,
    this.isLeadingIcon = true,
    this.isEnabled = true,
    this.isSolid = true,
    this.hasBorder = false,
    this.borderColor,
    this.iconColor,
    this.isCircle=false,
  });
}
