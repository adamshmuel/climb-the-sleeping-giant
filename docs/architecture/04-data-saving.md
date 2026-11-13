# 4. Data saving

Part of [the architecture](../architecture.md).


Spec 1 saves nothing: banked eggs are lost when a player leaves (spec 1, section 11). From spec 3, player data is saved with **ProfileStore**, installed through Wally into `ServerScriptService.ServerPackages`. Each player's data has one key, `User_<UserId>`. ProfileStore saves on leave and on shutdown by itself.
