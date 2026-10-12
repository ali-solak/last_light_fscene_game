/// What the keeper can interact with.
enum InteractKind { mirror, lamp, bell }

/// What holding interact will do, for the prompt over the world.
enum PromptVerb { aim, aiming, turn, raise, relight, ring }

/// Marks an entity the keeper can `interact` with. The owning feature keeps
/// [holdSeconds], [enabled], [continuous] and [verb] current (a toppled
/// mirror holds longer and says "raise", a lit lamp is not interactable);
/// the keeper feature only reads it.
///
/// A [continuous] one is used for as long as interact is held (an upright
/// mirror is aimed while held); the owning feature acts every step the
/// keeper is interacting with it, and no `Interacted` is sent.
final class Interactable(
  final InteractKind kind, {
  var double holdSeconds = 0.4,
  var bool enabled = true,
  var double range = 1.5,
  var PromptVerb verb = .turn,
  var bool continuous = false,
});
