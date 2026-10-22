/// Pictures used as counting objects (Number Quest) and picture cards
/// (Memory Match). Drawn by `widgets/math_pictures.dart`.
enum MathPicture {
  apple('apple', 'apples'),
  orange('orange', 'oranges'),
  star('star', 'stars'),
  fish('fish', 'fish'),
  flower('flower', 'flowers'),
  balloon('balloon', 'balloons'),
  heart('heart', 'hearts'),
  sun('sun', 'suns'),
  moon('moon', 'moons'),
  tree('tree', 'trees');

  const MathPicture(this.label, this.plural);

  final String label;
  final String plural;

  /// Pictures that read well when many are shown at once for counting.
  static const countable = [apple, orange, star, fish, flower, balloon];
}
