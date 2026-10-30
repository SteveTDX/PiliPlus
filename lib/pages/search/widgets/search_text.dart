import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:material_ui/material_ui.dart';

class SearchText extends StatelessWidget {
  final String text;
  final ValueChanged<String>? onTap;
  final ValueChanged<String>? onLongPress;
  final VoidCallback? onDelete;
  final double? fontSize;
  final Color? bgColor;
  final Color? textColor;
  final TextAlign? textAlign;
  final double? height;
  final EdgeInsets padding;
  final BorderRadius borderRadius;
  final int? maxLines;
  final TextOverflow? overflow;

  const SearchText({
    super.key,
    required this.text,
    this.onTap,
    this.onLongPress,
    this.onDelete,
    this.fontSize,
    this.bgColor,
    this.textColor,
    this.textAlign,
    this.height,
    this.padding = const .symmetric(horizontal: 11, vertical: 5),
    this.borderRadius = const .all(.circular(6)),
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    late final colorScheme = ColorScheme.of(context);
    final hasLongPress = onLongPress != null;
    final textColor = this.textColor ?? colorScheme.onSurfaceVariant;
    final textWidget = Text(
      text,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
      style: TextStyle(fontSize: fontSize, height: height, color: textColor),
    );
    return Material(
      color: bgColor ?? colorScheme.onInverseSurface,
      borderRadius: borderRadius,
      child: InkWell(
        onTap: () => onTap?.call(text),
        onLongPress: hasLongPress ? () => onLongPress!(text) : null,
        onSecondaryTap: hasLongPress && !PlatformUtils.isMobile
            ? () => onLongPress!(text)
            : null,
        borderRadius: borderRadius,
        child: Padding(
          padding: padding,
          child: onDelete == null
              ? textWidget
              : Row(
                  mainAxisSize: .min,
                  children: [
                    Flexible(child: textWidget),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: onDelete,
                      borderRadius: borderRadius,
                      child: Padding(
                        padding: const .symmetric(horizontal: 3, vertical: 2),
                        child: Icon(Icons.cancel, size: 16, color: textColor),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
