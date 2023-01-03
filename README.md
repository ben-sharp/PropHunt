

# Prop Hunt aka Hide n Seek GTA V (FiveM)
- [Prop Hunt aka Hide n Seek GTA V (FiveM)](#prop-hunt-aka-hide-n-seek-gta-v-fivem)
- [Installation](#installation)
  - [Dependencies](#dependencies)
- [Todos / Ideas](#todos--ideas)

Popular gamemode Prop Hunt brought to FiveM, the `hiders` team transform into
game objects and place themselves within the game strategically to hide from the `hunters` team, lasting as along as possible to gain the best score.

- `hunters` lose HP using guns but not melee weapons
- `hiders` only have 1 HP when hidden as a prop
- `hiders` become `hunters` after they die
- `hiders` gain points for time alive
 

# Installation
Clone the repo and add its contents to a folder called `PropHunt` inside your `resources` folder. Make sure you have the [Dependencies](#dependencies) too.

## Dependencies
[PolyZone](https://github.com/mkafrin/PolyZone/releases) is required for the playzone boundaries, download `PolyZone.zip`, add it to `resources` as a folder named `PolyZone` and add `ensure PolyZone` to your `server.cfg` - use `start PolyZone` if it's not running. 

# Todos / Ideas
- [ ] send `hunters` away during a timer on respawn? (idea is they may know current hiders location and they may want to move)
- [ ] `hunters` could regain HP if they kill a `hider`?