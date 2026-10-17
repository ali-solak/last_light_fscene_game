part of '../island.dart';

/// The night look: dark, cool and foggy, deep occlusion, a heavy vignette,
/// a little grain, and god rays off the low moon (flutter_scene's moody
/// preset, tuned for a lit-by-lanterns island).
EnvironmentSettings nightLook(Skybox skybox) => EnvironmentSettings(
  skybox: skybox,
  toneMapping: ToneMappingMode.aces,
  exposure: 1.2,
  // Low ambient: a dark, readable moonlit night the lights carve into.
  environmentIntensity: 0.3,
  colorGradingEnabled: true,
  contrast: 1.2,
  saturation: 0.92,
  temperature: -0.14,
  bloomEnabled: true,
  bloomThreshold: 1.0,
  bloomIntensity: 0.2,
  bloomScatter: 0.72,
  // Sea haze: the engine's height fog, thickest just above the sea and
  // thinning up the slopes, a shade lighter than the night so distance
  // reads through it, glowing toward the moon. The rolling banks are
  // particles (weather).
  fogEnabled: true,
  fogMode: FogMode.exponential,
  fogColor: Vector3(0.055, 0.07, 0.105),
  fogDensity: 0.055,
  fogHeight: 0.5,
  fogHeightFalloff: 0.28,
  fogSkyColorInfluence: 0.35,
  fogMaxOpacity: 0.93,
  // Only a faint glow toward the moon: at eye level it sits on the
  // horizon, and a strong in-scatter washes the whole view out.
  fogSunInScatter: 0.08,
  fogSunInScatterExponent: 18,
  ambientOcclusionEnabled: true,
  ambientOcclusionMethod: AmbientOcclusionMethod.groundTruth,
  ambientOcclusionIntensity: 1.25,
  ambientOcclusionPower: 1.8,
  ambientOcclusionHalfResolution: true,
  screenSpaceReflectionsEnabled: true,
  screenSpaceReflectionsIntensity: 0.9,
  vignetteEnabled: true,
  vignetteIntensity: 0.5,
  vignetteRadius: 0.65,
  // Moonlight through the gaps between the tower, the rocks and the cottage.
  godRaysEnabled: true,
  godRaysIntensity: 0.6,
  godRaysDensity: 0.7,
  godRaysAnisotropy: 0.8,
  godRaysStepCount: 32,
  godRaysMaxDistance: 90,
  godRaysColor: Vector3(0.45, 0.58, 0.95),
);

/// The dawn look: warm, open and clear; the build happens in it.
EnvironmentSettings dawnLook(Skybox skybox) => EnvironmentSettings(
  skybox: skybox,
  toneMapping: ToneMappingMode.aces,
  exposure: 1.0,
  environmentIntensity: 0.75,
  colorGradingEnabled: true,
  contrast: 1.05,
  saturation: 1.08,
  temperature: 0.12,
  bloomEnabled: true,
  bloomThreshold: 1.4,
  bloomIntensity: 0.1,
  bloomScatter: 0.7,
  fogEnabled: true,
  fogMode: FogMode.exponential,
  fogColor: Vector3(0.62, 0.48, 0.40),
  fogDensity: 0.006,
  fogHeight: 1.0,
  fogHeightFalloff: 0.12,
  ambientOcclusionEnabled: true,
  ambientOcclusionMethod: AmbientOcclusionMethod.groundTruth,
  ambientOcclusionIntensity: 1.0,
  ambientOcclusionHalfResolution: true,
  vignetteEnabled: true,
  vignetteIntensity: 0.25,
  screenSpaceReflectionsEnabled: true,
  screenSpaceReflectionsIntensity: 0.6,
  godRaysEnabled: true,
  godRaysIntensity: 0.5,
  godRaysDensity: 0.4,
  godRaysColor: Vector3(1.0, 0.85, 0.65),
);
