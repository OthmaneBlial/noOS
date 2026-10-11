"""Render a reproducible README progress table from explicitly verified gates."""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]


def render():
    milestones = json.loads((ROOT / "docs/progress.json").read_text())["milestones"]
    gates = [value for item in milestones for value in item["gates"].values()]
    assert len(milestones) == 8 and len(gates) == 40
    assert all(type(value) is bool for value in gates)
    percentage = sum(gates) * 100 / len(gates)
    lines = [f"## Roadmap — {percentage:g}%", "",
             "Progress counts verified gates, including the advanced roadmap. Planned work earns no credit.",
             "", "| Milestone | Verified |", "| --- | --- |"]
    for index, item in enumerate(milestones, 1):
        values = list(item["gates"].values())
        lines.append(f"| {index}. {item['name']} | {sum(values)}/{len(values)} |")
    return "\n".join(lines)


def main():
    readme = ROOT / "README.md"
    content = readme.read_text()
    updated, count = re.subn(r"<!-- progress:start -->.*?<!-- progress:end -->",
                            f"<!-- progress:start -->\n{render()}\n<!-- progress:end -->",
                            content, flags=re.S)
    assert count == 1, "README must have one progress region"
    if "--check" in sys.argv:
        assert content == updated, "Run python3 tools/progress.py to refresh README"
    else:
        readme.write_text(updated)
    print(render().splitlines()[0])


if __name__ == "__main__":
    main()
