# Hippolyzer Client Visitant

This species adapts the [Hippolyzer](../../instruments/hippolyzer/README.md) protocol analyzer into a standalone OpenSim client visitant (Deep Sea variant).

## Overview

Hippolyzer is primarily a "man-in-the-middle" instrument for inspecting OpenSim traffic, but it exposes a client library that can be used to connect directly to simulators. This visitant leverages `hippolyzer.lib.client` to implement the standard Visitant protocols.

## Usage

See `0.17.0/README.md` (if available) or simply use the standard `run_visitant.sh` interface.

## Reference

*   [Hippolyzer Instrument](../../instruments/hippolyzer/README.md)
