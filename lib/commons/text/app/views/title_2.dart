part of 'custom_text_library.dart';

class Title2 extends BaseTextWidget {
  Title2({
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
  }) : super(style: TextStyles.title2().copyWith(color: color));
}
