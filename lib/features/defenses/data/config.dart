part of '../defenses.dart';

/// Salt: how long a line is, how much crossing it can take (crab-seconds),
/// and the path cost it adds (the horde goes round if it can).
const double saltLength = 5;
const double saltWidth = 0.9;
const double saltStrength = 14;
const double saltPathCost = 40;

/// A barricade: how long, how thick the wall cells are, and how much
/// chewing it takes.
const double barricadeLength = 3.2;
const double barricadeThickness = 0.6;
const double barricadeHp = 60;

/// A tap or drag this close to a placed defense works on it; defenses keep
/// this clear of the tower and each other.
const double defensePickRadius = 1.6;
const double defenseTowerClearance = 6;
const double defenseSpacing = 2.0;
const double defenseSnapDeg = 15;
