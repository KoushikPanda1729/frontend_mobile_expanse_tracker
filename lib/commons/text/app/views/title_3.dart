part of 'custom_text_library.dart';

class Title3 extends BaseTextWidget{
  Title3({
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
  }):super(style: TextStyles.title3().copyWith(color: color));
}