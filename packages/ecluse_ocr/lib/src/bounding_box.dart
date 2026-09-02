import 'package:meta/meta.dart';

/// Rectangle dans le repère de l'image d'origine (pixels).
///
/// L'origine est le coin haut-gauche. `x + width` et `y + height` sont
/// dans l'image (exclusifs).
@immutable
class BoundingBox {
  const BoundingBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.pageIndex,
  })  : assert(width > 0, 'width doit être > 0'),
        assert(height > 0, 'height doit être > 0'),
        assert(pageIndex >= 0);

  final int x;
  final int y;
  final int width;
  final int height;

  /// Index de page (0-based) — utile pour les PDF multi-pages.
  final int pageIndex;

  int get right => x + width;
  int get bottom => y + height;

  @override
  bool operator ==(Object other) =>
      other is BoundingBox &&
      other.x == x &&
      other.y == y &&
      other.width == width &&
      other.height == height &&
      other.pageIndex == pageIndex;

  @override
  int get hashCode => Object.hash(x, y, width, height, pageIndex);

  @override
  String toString() => 'BoundingBox(p$pageIndex, $x,$y ${width}x$height)';
}
