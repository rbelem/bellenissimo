import 'ingredient.dart';

/// Approximate conversion data for common baking ingredients, using US
/// volume measures (1 cup = 240 ml).
///
/// These are starting points for recipe entry, not truth: densities vary
/// by brand and packing. The app should let users override any of them.
const seedIngredients = <String, Ingredient>{
  'water': Ingredient('water', gramsPerMl: 1.0),
  'milk': Ingredient('milk', gramsPerMl: 1.02),
  'oil': Ingredient('oil', gramsPerMl: 0.9),
  'honey': Ingredient('honey', gramsPerMl: 1.42),
  'flour': Ingredient('flour', gramsPerMl: 0.5),
  'whole_wheat_flour': Ingredient('whole_wheat_flour', gramsPerMl: 0.53),
  'sugar': Ingredient('sugar', gramsPerMl: 0.83),
  'brown_sugar': Ingredient('brown_sugar', gramsPerMl: 0.89),
  'powdered_sugar': Ingredient('powdered_sugar', gramsPerMl: 0.55),
  'butter': Ingredient('butter', gramsPerMl: 0.95),
  'cocoa': Ingredient('cocoa', gramsPerMl: 0.42),
  'salt': Ingredient('salt', gramsPerMl: 1.2),
  'egg': Ingredient('egg', gramsPerPiece: 50),
  'egg_yolk': Ingredient('egg_yolk', gramsPerPiece: 18),
  'egg_white': Ingredient('egg_white', gramsPerPiece: 30),
};
