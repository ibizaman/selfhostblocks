import sys
from itertools import takewhile


def skip_to_heading(lines, heading):
    for line in lines:
        if line == heading:
            return True
    return False


def extract_section(changelog_path, version):
    target_heading = f"# {version}"

    with open(changelog_path) as f:
        lines = (line.rstrip("\n") for line in f)

        if not skip_to_heading(lines, target_heading):
            return None

        return "\n".join(takewhile(lambda line: not line.startswith("# "), lines))


if len(sys.argv) != 3:
    print(f"Usage: {sys.argv[0]} <changelog_path> <version>", file=sys.stderr)
    sys.exit(1)

changelog_path = sys.argv[1]
version = sys.argv[2]

section = extract_section(changelog_path, version)
if section is None:
    print(f"No section found for version {version}", file=sys.stderr)
    sys.exit(1)

print(section)
