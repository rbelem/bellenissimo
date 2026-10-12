/// The physical kind a [Unit] measures.
enum UnitKind { mass, volume, count }

/// Kitchen units. Every unit carries its factor into its kind's canonical
/// base: grams for mass, millilitres for volume, pieces for count.
enum Unit {
  g(UnitKind.mass, 1),
  kg(UnitKind.mass, 1000),
  oz(UnitKind.mass, 28.3495),
  lb(UnitKind.mass, 453.592),
  ml(UnitKind.volume, 1),
  l(UnitKind.volume, 1000),
  tsp(UnitKind.volume, 5),
  tbsp(UnitKind.volume, 15),
  // US legal cup; metric cups (250 ml) are a user setting, not a unit.
  cup(UnitKind.volume, 240),
  flOz(UnitKind.volume, 29.5735),
  piece(UnitKind.count, 1);

  const Unit(this.kind, this.canonicalFactor);

  final UnitKind kind;

  /// Amount of the canonical base (g, ml, or pieces) in one of this unit.
  final double canonicalFactor;
}
