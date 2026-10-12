import 'package:scene_dash_v2/scene_dash_v2.dart';

/// A world-space label (a widget quad facing +Z) that should always turn
/// to face the camera, so it never reads mirrored from behind. The camera
/// feature yaws every tagged node toward the eye each render.
final class const Billboard() implements Tag;
