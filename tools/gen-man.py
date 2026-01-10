#!/usr/bin/env python3
import re
from datetime import datetime
from pathlib import Path


def parse_header(script_path: Path) -> dict:
    data = {"description": "", "usage": "", "parameters": []}
    lines = script_path.read_text(encoding="utf-8").splitlines()
    in_header = True
    current = ""
    for line in lines:
        if in_header:
            if line.startswith("# PARAMETERS:"):
                current = "parameters"
                continue
            if line.startswith("# DESCRIPTION:"):
                data["description"] = line.split(":", 1)[1].strip()
                current = "description"
                continue
            if line.startswith("# USAGE:"):
                data["usage"] = line.split(":", 1)[1].strip()
                current = "usage"
                continue
            if line.startswith("# EXAMPLE:"):
                current = "example"
                continue
            if line.startswith("#"):
                if current == "parameters" and re.match(r"#\s+\-\-", line):
                    data["parameters"].append(line.lstrip("# ").rstrip())
                continue
            if not line.startswith("#!") and line.strip():
                in_header = False
        else:
            break
    return data


def main() -> None:
    repo_root = Path(__file__).resolve().parents[1]
    script = repo_root / "inc" / "isoforge.sh"
    man_path = repo_root / "docs" / "man" / "isoforge.1"
    version = (repo_root / "VERSION").read_text(encoding="utf-8").strip()

    header = parse_header(script)
    usage = header["usage"] or "isoforge [options]"
    description = header["description"] or "TUI for downloading and flashing ISOs to USB."
    date = datetime.utcnow().strftime("%Y-%m-%d")

    lines = [
        f'.TH ISOFORGE 1 "{date}" "isoforge {version}" "User Commands"',
        ".SH NAME",
        "isoforge \\- TUI for downloading and flashing ISOs to USB, including Ventoy multi-ISO.",
        ".SH SYNOPSIS",
        ".B isoforge",
        usage.replace("isoforge", "").strip(),
        ".SH DESCRIPTION",
        description,
        ".SH OPTIONS",
    ]

    if header["parameters"]:
        for param in header["parameters"]:
            parts = re.split(r"\s{2,}", param, maxsplit=1)
            flag = parts[0]
            desc = parts[1] if len(parts) > 1 else ""
            lines.append(".TP")
            lines.append(f".B {flag}")
            if desc:
                lines.append(desc)
    else:
        lines.append(".TP")
        lines.append("No documented options.")

    lines.extend(
        [
            ".SH FILES",
            ".TP",
            ".I /usr/share/isoforge/config.json",
            "Default configuration when installed system-wide.",
        ]
    )

    man_path.parent.mkdir(parents=True, exist_ok=True)
    man_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote {man_path}")


if __name__ == "__main__":
    main()
