#!/bin/bash
set -e

# Build the Mimic instrument
echo "Building Mimic..."
dotnet build src/Mimic.csproj
