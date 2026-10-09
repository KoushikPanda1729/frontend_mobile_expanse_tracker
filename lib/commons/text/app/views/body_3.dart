part of 'custom_text_library.dart';

class Body3 extends BaseTextWidget {
  Body3({
    super.key,
    required super.text,
    super.textAlign,
    super.textDirection,
    super.locale,
    super.softWrap,
    super.overflow,
    super.maxLines,
    super.semanticsLabel,
    super.textWidthBasis,
    super.textHeightBehavior,
    super.textScaler,
    Color? color,
  }) : super(style: TextStyles.body3().copyWith(color: color));

}