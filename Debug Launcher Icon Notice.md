This project uses two launcher aliases so users can switch between two icons in release builds.
In release mode, only those aliases act as the launchers, as long as the main activity does not contain its own launcher entry.

Why two icons appear
Flutter automatically treats the main activity as a launcher during debug builds.
If the main activity also has a launcher intent defined in the manifest, and an alias also has one, the launcher will display two icons.
This can also happen in release builds if the main activity still contains a launcher intent, since both the alias and the activity are treated as launchers.

How to avoid the duplicate icon
Before running the project in debug, remove the launcher intent from the main activity in the manifest (LINES 41 - 44).
Doing this leaves only the alias active, which results in a single launcher icon.
Alternatively, disable one of the aliases if needed.

Important
This adjustment applies only to debugging.
Debug builds require at least one launcher entry.
Release builds should keep only the alias entries as launchers, and the main activity should have no launcher intent.
