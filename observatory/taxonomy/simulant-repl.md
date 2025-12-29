# Simulant REPL Documentation

This document outlines the known console commands available in OpenSim Core 0.9.3.

## General Commands

*   `help [command]` - Get help on a command.
*   `quit` or `shutdown` - Shutdown the server.
*   `show uptime` - Show server uptime.
*   `show version` - Show server version.
*   `show info` - Show general server info.
*   `show modules` - Show loaded modules.
*   `command-script <script>` - Run a command script from file.

## Region Commands

*   `change region <region name>` - Change current console region context.
*   `create region ["region name"] <region_file.ini>` - Create a new region.
*   `delete-region <name>` - Delete a region from disk.
*   `remove-region <name>` - Remove a region from the simulator (but keep data).
*   `restart` - Restart the currently selected region(s).
*   `show regions` - Show region data.
*   `show ratings` - Show rating data.

## Estate Commands

*   `estate create <owner UUID> <estate name>` - Create a new estate.
*   `estate set owner <estate-id> [<UUID> | <Firstname> <Lastname>]` - Set estate owner.
*   `estate set name <estate-id> <new name>` - Set estate name.
*   `estate link region <estate ID> <region ID>` - Attach a region to an estate.
*   `estate show` - Show all estates.

## User Management

*   `create user <first> <last> <pass> <email> [<uuid>]` - Create a new user.
*   `reset user password <first> <last> <newpass>` - Reset a user's password.
*   `login enable` - Enable simulator logins.
*   `login disable` - Disable simulator logins.
*   `login status` - Show login status.
*   `kick user <first> <last> [--force] [message]` - Kick a user.
*   `show users [full]` - Show users currently on the region.

## Object Management

*   `backup` - Persist currently unsaved object changes immediately.
*   `force update` - Force update of all objects on clients.
*   `delete object owner <UUID>`
*   `delete object creator <UUID>`
*   `delete object id <UUID-or-localID>`
*   `delete object name [--regex] <name>`
*   `delete object pos <start-coord> <end-coord>`
*   `delete object outside`
*   `show object id [--full] <UUID-or-localID>`
*   `show object name [--full] [--regex] <name>`
*   `show object owner [--full] <OwnerID>`
*   `show object pos [--full] <start-coord> <end-coord>`
*   `edit scale <name> <x> <y> <z>`
*   `rotate scene <degrees> [centerX, centerY]`
*   `scale scene <factor>`
*   `translate scene xOffset yOffset zOffset`

## Land Management

*   `land clear` - Clear all parcels.
*   `land show [<local-land-id>]` - Show parcel info.

## Archiving (OAR)

*   `save oar [options] <OAR path>`
*   `load oar [options] <OAR path>`
*   `save xml <file>` (Deprecated)
*   `load xml <file>` (Deprecated)
*   `save xml2 <file>`
*   `load xml2 <file>`

## Archiving (IAR)

*   `save iar <first> <last> <inventory path> <password> <IAR path>`
*   `load iar <first> <last> <IAR path> [<password>]`
