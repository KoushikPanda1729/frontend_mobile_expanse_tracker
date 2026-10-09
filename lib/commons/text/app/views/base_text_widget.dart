import 'package:expensetracker/commons/text/domain/entities/text_entity.dart';
import 'package:flutter/material.dart';

abstract class BaseTextWidget extends StatelessWidget {
  final TextEntity textEntity;
  BaseTextWidget({
    super.key,
    required String text,
    required TextStyle style,
    Color? color, 
    TextAlign? textAlign,
    TextDirection? textDirection,
    Locale? locale,
    bool? softWrap,
    TextOverflow? overflow,
    int? maxLines,
    String? semanticsLabel,
    TextWidthBasis? textWidthBasis,
    TextHeightBehavior? textHeightBehavior,
    TextScaler? textScaler,
  }):textEntity = TextEntity(
    text: text,
    style: color != null ? style.copyWith(color: color) : style,
    textAlign: textAlign,
    textDirection: textDirection,
    locale: locale,
    softWrap: softWrap,
    overflow: overflow,
    maxLines: maxLines,
    semanticsLabel: semanticsLabel,
    textWidthBasis: textWidthBasis,
    textHeightBehavior: textHeightBehavior,
    textScaler: textScaler,
  );

  @override
  Widget build(BuildContext context) {
    return Text(
      textEntity.text,
      style: textEntity.style,
      textAlign: textEntity.textAlign,
      textDirection: textEntity.textDirection,
      locale: textEntity.locale,
      softWrap: textEntity.softWrap,
      overflow: textEntity.overflow,
      maxLines: textEntity.maxLines,
      semanticsLabel: textEntity.semanticsLabel,
      textWidthBasis: textEntity.textWidthBasis,
      textHeightBehavior: textEntity.textHeightBehavior,
    );
  }
}
