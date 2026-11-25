{ writers }:
writers.writePython3Bin "extract-changelog" { } (builtins.readFile ./extract-changelog.py)
