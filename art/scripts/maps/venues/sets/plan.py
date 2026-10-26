"""Where each cutscene set stands in the Sets venue (scene space; the game builds it at Venues.SETS)."""

STUDY = (0.0, 0.0)  # Diavolo's study: x -12..12, z -10..10, 14 high; the window in the north wall
SHRINE = (120.0, 0.0)  # the Muertos' shrine: x -11..11, z -16..14, 20 high; the altar at the north end
ACE = (240.0, 0.0)  # Ace's monitor room: x -12..10, z -9..9, 12 high; the pantry beyond its east wall
PANTRY = (258.0, 0.0)  # the Butler's pantry: x -7..7, z -6..6, 11 high; its door into Ace's room on the west
LOCKER = (360.0, 0.0)  # the Bureau's locker room: x -11..11, z -7..7, 11 high
FLAT = (360.0, 60.0)  # the Muerto's flat: x -9..9, z -7..7, 10 high; the wide window in the north wall
WAREHOUSE = (520.0, 0.0)  # the warehouse: x -36..36, z -26..26, 26 high
# The win cutscenes' rooms (src/shared/Cinema/WinCuts.luau: each cut's room.at, the star's mark, facing -z):
WRITER = (0.0, 70.0)  # the Coven's Sealed one (finalPage): x -8.5..8.5, z -6.5..8.2, 13 high; the window north
OFFICE = (120.0, 70.0)  # the Bureau's Sealed one (caseClosed): x -8.5..8.5, z -8.4..8, 12 high; the board north
HALL = (720.0, 0.0)  # the Bureau's Godhood one (checkmate): x -40..40, z -58..36, 48 high; the board in its middle
ROOFTOP = (900.0, 0.0)  # the Coven's Godhood one (newWorld): the roof x -20..20, z -7.25..17; the street 70 below

BOUNDS = ((-70.0, -75.0, -90.0), (930.0, 80.0, 90.0))
