# BF2142 Unlocker
![Logo](bf2142unlocker.png)

## Description
This project aims to unlock all weapons in BF2142! You can equip/customize your soldier ingame. <br />
The unlocker emulates the necessary login and unlock server to play with your friends in coop/multiplayer with all features (except squad drones, because bot's cannot handle them). <br />
The unlocker gives you the abillity to add 64 coop maps (see below *"Optional requirements"*). <br />
**Warning:** *The actual version is slightly hacky and not stable!*

## Requirements:
- Battlefield 2142 with the original executable.

## Downloads
- [Download BF2142 Unlocker v0.9 (Windows)](https://github.com/Dankr4d/BF2142Unlocker/releases/download/v0.9/BF2142Unlocker_v0.9_win.zip)
- [Download BF2142 Unlocker v0.9 (Linux)](https://github.com/Dankr4d/BF2142Unlocker/releases/download/v0.9/BF2142Unlocker_v0.9_linux.zip)

## How to use:
- Start the BF2142Unlocker:
  - Windows: BF2142Unlocker.bat
  - Linux: gui
- If your BF2142 game folder is read only, you need to allow elevatedio to run as administrator. Otherwise just cancel the elevation request.
- Set your Battlefield 2142 client path in settings.
- Goto settings tab and start login server "Host login server only".
- Goto join tab, set your playername and your local ip address (localhost and 127.0.0.1 as well as ipv6 addresses are not supported).
  <br />
  *Be carefull with the ip address you want to join. If BF2142 cannot connect to given ip address, BF2142 will stuck in a black screen.*
- Click on join and setup your match ingame (singleplayer or lan/coop).
- *Optional: You could also set the Battlefield 2142 Server path in settings menu to configure serversettings and start the server in Host tab.*


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

## Optional requirements
### Install the Battlefield 2142 Server (to enable configuration in the Host tab)
- Windows: ftp://ftp.bf-games.net/server-files/bf2142/Battlefield_2142_Server_Unranked.exe
- Linux: ftp://ftp.bf-games.net/server-files/bf2142/bf2142-linuxded-1.10.112.0-installer.rar
### 64 Coop Maps
- Goto https://battlefield2142.co/ and click on "Download Map Pack".
- Unzip downloaded mappack.
- Start BF2142Unlocker and go to Settings tab.
- Click on "Copy 64 coop maps (client)" and select the Levels folder from extracted zip file (*Warning: Battlefield 2142 client path must be set*).
- Click on "Copy 64 coop maps (server)" and select the Levels folder from extracted zip file (*Warning: Battlefield 2142 server path must be set*).

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
