part of '../island.dart';

/// Slopes steeper than this are not walkable.
const double islandMaxWalkSlopeDeg = 40;

/// At high tide crabs wade no deeper than this; the next band down is the
/// tide-pool path, walkable only at low tide.
const double islandWadeDepth = -1.6;
const double islandTidePathDepth = -2.6;

/// How far the sea plane moves for low tide.
const double islandTideShift = 1.0;

/// Aim ray marching onto the HeightGrid.
const double islandAimStep = 0.25;
const double islandAimMaxDistance = 220;

/// The bell stands this far from the cottage anchor, in the cottage's frame.
const double islandBellOffsetX = 4.2;
const double islandBellOffsetZ = -1.5;

/// A height change this small is a step, not a wall, whatever the cell's
/// slope flag says (the rasteriser marks some path edges steep).
const double islandMaxStep = 0.45;

/// The part of an occluder's radius nothing can walk through.
const double islandSolidFraction = 0.85;

/// Occluder radii for the big static pieces.
const double islandCottageRadius = 3.2;
const double islandLighthouseRadius = 3.6;

/// The sea plane.
const double islandSeaSize = 600;
const int islandSeaSegments = 96;

/// Sky tint colours (dawn 0..1 drives sky.fmat).
const double islandSkyTweenSeconds = 3.0;

/// Grass scatter.
const int islandGrassCount = 160;
const int islandGrassSeed = 7;
const double islandGrassMinHeight = 0.8;

/// The moon: low over the sea so shadows run long and god rays stream
/// past the tower; the sky draws its disc exactly opposite this.
final Vector3 islandMoonDirection = Vector3(-0.5, -0.3, 0.8);
const double islandMoonNight = 1.5;
const double islandMoonDawn = 2.6;

/// The ground palette's road colours: the light sand of the trails.
const Set<int> islandRoadColumns = {12, 13};

/// The keeper climbs slopes up to this steep and steps up this much more
/// per stride (kerbs, the boardwalk edge); anything steeper is a cliff.
const double islandKeeperMaxSlopeDeg = 52;
const double islandKeeperStepUp = 0.04;

/// The ground palette's grass colours: what burns.
const Set<int> islandGrassColumns = {7, 8};

/// A lightning flash lights the island this much more than the moon.
const double islandLightningBoost = 9;

/// The cottage window's warm area light.
const double islandWindowLight = 7;
