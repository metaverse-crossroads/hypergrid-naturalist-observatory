# The Sequencer

A lightweight .NET 8 Console Application for generating OpenSim database injection SQL.

## Purpose

To bypass complex OpenSim runtime dependencies and "God Object" instruments (like Mimic) when seeding the world with test data. The Sequencer produces raw SQL which is then piped into SQLite databases.

## Usage

Built to `vivarium/sequencer/Sequencer.dll` by `build.sh`.

### Generate User
```bash
dotnet Sequencer.dll gen-user --first "John" --last "Doe" --pass "secret" --uuid "..."
```

### Generate Prim
```bash
dotnet Sequencer.dll gen-prim --owner "..." --region "..." --posX 128 --posY 128 --posZ 40
```

## Constraints

* Zero dependencies (Vanilla .NET 8).
* Outputs raw SQL to STDOUT.
