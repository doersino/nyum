"""
Export recipe in Chowdown markdown format
https://github.com/clarklab/chowdown
"""

from pathlib import Path
from shutil import copy

from slugify import slugify

from . import Recipe


def to_chowdown_markdown(file_path: Path, img_path: str = "") -> list[str]:
    r = Recipe(file_path)
    ast = r.ast
    title = r.title
    description = r.metadata.get("description", "")
    output = []

    metadata = ast["metadata"]
    steps = ast["steps"]

    output.append("---")
    output.append("layout: recipe")
    output.append(f"title: {title}")
    if img_path:
        output.append(f"image: {img_path}")
    for key, value in metadata.items():
        output.append(f"{key}: {value}")

    output.append(" ")
    output.append("ingredients:")
    for item in ast["ingredients"]:
        name = item["name"]
        quantity = f"{item['quantity']} {item['units']}".strip()
        ingredient = f"*{quantity}* {name}" if quantity else name
        line = f'- "{ingredient}"'
        output.append(line)

    output.append(" ")
    output.append("directions:")

    for step in steps:
        method = ""
        for item in step:
            if item["type"] == "text":
                method += item["value"]
            elif item["type"] in "cookware":
                method += item["name"]
            elif item["type"] in "timer":
                method += f"{item['quantity']} {item['units']}".strip()
            elif item["type"] == "ingredient":
                name = item["name"]
                quantity = f"{item['quantity']} {item['units']}".strip()
                ingredient = f"`{quantity}` {name}" if quantity else name
                method += name
        output.append(f"- {method}")

    output.append("")
    output.append("---")

    output.append("")
    output.append(description)

    return output


def migrate_cook_to_chowdown(cook_dir: Path, output_dir: Path) -> int:
    """Migrate a directory of cook recipes to chowdown files"""
    output_dir.mkdir(exist_ok=True)
    output_dir_recipes = output_dir / '_recipes'
    output_dir_recipes.mkdir(exist_ok=True)
    output_dir_images = output_dir / 'images'
    output_dir_images.mkdir(exist_ok=True)
    cook_files = list(cook_dir.glob("*/*.cook"))
    cook_files += list(cook_dir.glob("*.cook"))
    for file_path in cook_files:
        title = file_path.stem
        slug_title = slugify(title)

        img_path = file_path.with_suffix(".jpg")
        if img_path.exists():
            chow_img_path = output_dir_images / f"{slug_title}.jpg"
            copy(img_path, chow_img_path)
            img_path = f"{slug_title}.jpg"
        else:
            img_path = ""

        output = to_chowdown_markdown(file_path, img_path=img_path)

        chow_path = output_dir_recipes / f"{slug_title}.md"
        with open(chow_path, "w") as f:
            f.writelines([x + "\n" for x in output])
    return len(cook_files)
