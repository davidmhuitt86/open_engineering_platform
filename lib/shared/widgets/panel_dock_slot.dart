/// Which edge of the window a [DockablePanel] currently occupies.
/// Deliberately a closed set of permanent slots, not a free (x, y)
/// position (user-requested: "they shouldn't have ever been able to
/// free float. they just need a permanent place to sit in the window
/// with the ability to move that panel to another place as well as
/// resize").
enum PanelDockSlot {
  left,
  right,
  top,
  bottom;

  String get label => switch (this) {
        PanelDockSlot.left => 'Left',
        PanelDockSlot.right => 'Right',
        PanelDockSlot.top => 'Top',
        PanelDockSlot.bottom => 'Bottom',
      };
}
