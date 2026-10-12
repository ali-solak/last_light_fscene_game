part of '../fire.dart';

/// A grass cell burns this long (seconds, varied per cell).
const double fireBurnMin = 3.5;
const double fireBurnMax = 6;

/// Heat a burning cell pours into each grassy neighbour per second; a cell
/// catches at 1. Downwind neighbours get up to [fireWindBias] times more,
/// upwind ones less.
const double fireSpreadHeat = 0.24;
const double fireWindBias = 2.2;

/// A storm damps fire: slower to spread, quicker to burn out.
const double fireStormDamp = 0.65;

/// A moth's blast sets the grass alight this far round.
const double fireMothRadius = 2.5;

/// What a burning cell adds to the light map.
const double fireLightIntensity = 1.2;

/// How big a flame card stands and how bright the fire draws.
const double fireCardScale = 1.0;
const double fireBrightness = 0.8;

// Visuals.
const int fireLights = 6;
const double fireLightSpacing = 5;
const double fireLightIntensity3d = 2.6;
const double fireLightRange = 5;

/// Flame particles per burning cell per second, and the most per frame.
const double fireParticlesPerCell = 3;
const int fireParticleBudget = 30;
