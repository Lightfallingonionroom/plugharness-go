/// Secondary destinations the drawer (or something inside it) can open.
/// Pages the drawer opens; [settingsSearch] is ⚙ held down. 快捷入口 stores
/// these by [Enum.name], so a rename here is a change to stored preferences.
/// Stored by [Enum.name], so a rename is a change to stored preferences:
/// add values, never rename or reorder the ones that already exist.
enum DrawerDestination { web, remote, plugins, engine, settings, settingsSearch, features, schedules, purge, terminal }
