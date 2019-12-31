# BF2142 Unlocker
![Logo](bf2142unlocker.png)

## Description
This project aims to unlock all weapons in BF2142! <br />
You can equip/customize your soldier ingame. <br />
The unlocker emulates all necessary servers (login and unlock server) to play with your friends in coop/multiplayer **with all features** (except squad drones, because bot's cannot handle them). <br />
The unlocker gives you the abillity to add 64 coop maps (see below *"Optional requirements"*). <br />
**Warning:** *The actual version is slightly hacky and not stable!*

## What does not work?
- Switching mods is currently wihtout any functionality, because auto joining the server does not work with the modPath parameter.
- Squad drones are disabled, because most of the time bots are endless spaming drones and stop moving.

## Screenshots (Linux version)
### GUI:
|   |   |
| - | - |
| ![Host menu](screenshots/gui_host.png) | ![Join menu](screenshots/gui_join.png) |
| ![Settings menu](screenshots/gui_settings.png) |
### Ingame:
|   |   |
| - | - |
| ![Ingame Recon](screenshots/ingame_recon.png) | ![Ingame Assault](screenshots/ingame_assault.png) |
| ![Ingame Engineer](screenshots/ingame_engineer.png) | ![Ingame Support](screenshots/ingame_support.png) |

## Requirements
### Install the Battlefield 2142 Server
- Windows: ftp://ftp.bf-games.net/server-files/bf2142/Battlefield_2142_Server_Unranked.exe
- Linux: ftp://ftp.bf-games.net/server-files/bf2142/bf2142-linuxded-1.10.112.0-installer.rar

## Optional requirements
### 64 Coop Maps
- Download and unzip ftp://ftp.bf-games.net/mods/bf2142/bf2142sp/2142_sp_1_5_2.zip
- Open BF2142Unlocker gui and go to settings tab (*Warning: Battlefield 2142 client and server path must be set*)
- Click on "Copy 64 coop maps (client)" and select the Levels folder from extracted zip file
- Click on "Copy 64 coop maps (server)" and select the Levels folder from extracted zip file

## Infos
- If your BF2142 game folder is read only, you need to allow elevatedio to run as administrator. Otherwise just cancel the elevation request.
- You need to set the BF2142 game path (and if you want to host the server, you also need to set the server path).
- To start the gui you need to execute the gui/gui.exe executable.
- Be carefull with the ip address you want to join. If BF2142 cannot connect to given ip address, BF2142 will stuck in a black screen.

## Downloads
- [Download BF2142 Unlocker v0.9](https://github.com/Dankr4d/BF2142Unlocker/archive/BF2142Unlocker_v0.9.zip)

---

## Compile (Windows 64 bit)
- Install MSYS2 (https://www.msys2.org/)
- Start MSYS2 MINGW64
- `pacman -Syu # Upgrade base`
- `pacman -Syu # Upgrade all packages`
- `pacman -S mingw-w64-x86_64-gcc mingw-w64-x86_64-openssl mingw-w64-x86_64-gtk3 mingw-w64-x86_64-python3-gobject make tar git`
- `cd /c/Users/$USER; mkdir projects; cd projects;`
- `git clone https://github.com/nim-lang/Nim.git`
- `cd Nim`
- `./build_all.bat # Build nim and all tools (like nimble)`
- `export PATH="$PATH:/c/Users/$USER/projects/Nim/bin"`
- `cd ..`
- `git clone https://github.com/Dankr4d/BF2142Unlocker`
- `cd BF2142Unlocker`
- `nim build.nims # Installs the dependencies and compiles the BF2142Unlocker`

## Compile (Linux)
- Install requierd packages: git gcc make tar wget gtk3 python-gobject vte3
- `nim build.nims`
- `nim -d:mingw build.nims # Cross compile for windows, but currently not working`

## Compile (Docker)
- `docker-compose up`
- `sh copydockerbuild.sh # Copies the compiled files from the docker container into the local build folder`
