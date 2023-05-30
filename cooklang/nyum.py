"""
Export recipe in nyum markdown format
https://github.com/doersino/nyum
"""

from pathlib import Path
from shutil import copy

import frontmatter
from slugify import slugify

from . import Recipe


def to_nyum_markdown(
    file_path: Path, category: str = "", img_path: str = ""
) -> list[str]:
    r = Recipe(file_path)
    ast = r.ast
    title = r.title
    output = []

    metadata = ast["metadata"]
    steps = ast["steps"]

    output.append("---")
    output.append(f'title: "{title}"')
    if category:
        output.append(f"category: {category}")
    if img_path:
        output.append(f"image: {img_path}")

    for key, value in metadata.items():
        if key == "tags":
            for tag in value.split(","):
                output.append(f"{tag}: ✓")
        else:
            output.append(f"{key}: {value}")

    output.append("---")
    output.append("")

    for step in steps:
        output.append("")
        method = ""
        ingredients = []
        for item in step:
            if item["type"] == "text":
                method += item["value"]
            elif item["type"] == "cookware":
                method += item["name"]
            elif item["type"] in "timer":
                method += f"{item['quantity']} {item['units']}".strip()
            elif item["type"] == "ingredient":
                name = item["name"]
                quantity = f"{item['quantity']} {item['units']}".strip()
                ingredient = f"`{quantity}` {name}" if quantity else name
                ingredients.append(ingredient)
                method += name

        if ingredients:
            for x in ingredients:
                output.append(f"* {x}")
            output.append("")

        output.append(f"> {method}")
        output.append("")
        output.append("---")

    del output[-1]  # remove last line break

    return output


NYUM_TAGS = ["favorite", "veggie", "vegan", "spicy", "sweet", "salty", "sour", "bitter"]
NYUM_ATTRIBUTES = ["description", "size", "source", "time", "author"]


def from_nyum_markdown(file_path: Path) -> tuple[dict, list[str]]:
    """Parse a nyum markdown file into cooklang"""
    with open(file_path) as fh:
        metadata, content = frontmatter.parse(fh.read())

    output = []
    for attr in NYUM_ATTRIBUTES:
        val = metadata.get(attr, "")
        if val:
            output.append(f">> {attr}: {val}")

    tags = []
    for attr in NYUM_TAGS:
        val = metadata.get(attr, "")
        if val:
            tags.append(attr)
    if tags:
        tags_val = ",".join(tags)
        output.append(f">> tags: {tags_val}")

    output.append("")
    steps = content.split("---")
    for step in steps:
        step_output = ""
        step = step.replace("> ", "")
        ingredients = []
        lines = step.split("\n")
        for line in lines:
            if line and line[0] == "*":
                if "`" in line:
                    x = line.split("`")
                    quantity = x[1].strip()
                    if len(x) > 2:
                        ingredient = x[2].strip()
                        cook_ingr = "@" + ingredient + "{" + quantity + "}"
                    else:
                        ingredient = quantity
                        cook_ingr = "@" + ingredient + "{}"
                else:
                    ingredient = line.replace("* ", "").strip()
                    cook_ingr = "@" + ingredient + "{}"
                pair = (ingredient, cook_ingr)
                ingredients.append(pair)
            else:
                if line:
                    step_output += line + " "

        for ingredient, cook_ingr in ingredients:
            if ingredient in step_output:
                step_output = step_output.replace(ingredient, cook_ingr, 1)
            else:
                step_output += " " + cook_ingr

        output.append(step_output)
        output.append("")

    return metadata, output


def migrate_nyum_to_cook(nyum_dir: Path, output_dir: Path) -> int:
    """Migrate a directory of nyum recipes to cook files"""
    nyum_files = list(nyum_dir.glob("*.md"))
    for file_path in nyum_files:
        meta, output = from_nyum_markdown(file_path)
        title = meta["title"]
        category = meta["category"]
        category_dir = output_dir / category
        category_dir.mkdir(exist_ok=True, parents=True)
        cook_path = category_dir / f"{title}.cook"

        img_path = file_path.with_suffix(".jpg")
        if img_path.exists():
            cook_img_path = category_dir / f"{title}.jpg"
            copy(img_path, cook_img_path)

        with open(cook_path, "w") as f:
            f.writelines([x + "\n" for x in output])
    return len(nyum_files)


def migrate_cook_to_nyum(cook_dir: Path, output_dir: Path) -> int:
    """Migrate a directory of cook recipes to nyum files"""
    output_dir.mkdir(exist_ok=True)
    cook_files = list(cook_dir.glob("*/*.cook"))
    cook_files += list(cook_dir.glob("*.cook"))
    for file_path in cook_files:
        if file_path.parent != cook_dir:
            category = file_path.parent.name
        else:
            category = ""
        title = file_path.stem
        slug_title = slugify(title)

        img_path = file_path.with_suffix(".jpg")
        if img_path.exists():
            nyum_img_path = output_dir / f"{slug_title}.jpg"
            copy(img_path, nyum_img_path)
            img_path = f"{slug_title}.jpg"
        else:
            img_path = ""

        output = to_nyum_markdown(file_path, category=category, img_path=img_path)

        nyum_path = output_dir / f"{slug_title}.md"
        with open(nyum_path, "w") as f:
            f.writelines([x + "\n" for x in output])
    return len(cook_files)
