import copy
import json
from pathlib import Path


def parse_cookware(item: str) -> dict[str, str]:
    """Parse cookware item
    e.g. #pot or #potato masher{}
    """
    if item[0] != "#":
        raise ValueError("Cookware should start with #")
    item = item.replace("{}", "")
    return {"type": "cookware", "name": item[1:], "quantity": ""}


def parse_quantity(item: str) -> list[str, str]:
    """Parse the quantity portion of an ingredient
    e.g. 2%kg
    """
    if "%" not in item:
        return [item, ""]
    return item.split("%", maxsplit=1)


def parse_ingredient(item: str) -> dict[str, str]:
    """Parse an ingredient string
    eg. @salt or @milk{4%cup}
    """
    if item[0] != "@":
        raise ValueError("Ingredients should start with @")
    if item[-1] != "}":
        return {
            "type": "ingredient",
            "name": item[1:],
            "quantity": "some",
            "units": "",
        }
    name, quantity = item.split("{", maxsplit=1)
    val, units = parse_quantity(quantity[0:-1])
    return {
        "type": "ingredient",
        "name": name[1:],
        "quantity": val or "some",
        "units": units,
    }


def parse_timer(item: str) -> dict[str, str]:
    """Parse timer string
    e.g. ~eggs{3%minutes} or ~{25%minutes}
    """
    if item[0] != "~":
        raise ValueError("Timer should start with ~")
    name, quantity = item.split("{", maxsplit=1)
    val, units = parse_quantity(quantity[0:-1])
    return {
        "type": "timer",
        "name": name[1:],
        "quantity": val,
        "units": units,
    }


def find_specials(step: str, start_char="#") -> list[str]:
    matches = []
    item = ""
    matching: bool = False
    specials = ["~", "@", "#"]
    for i, x in enumerate(step):
        if x == start_char:
            if start_char == "~" and step[i - 1] == "{":
                continue  # Skip - approx value in ingredient
            matching = True
            item += x
            continue
        if matching and x in specials:
            if " " in item:
                item = item.split(" ")[0]
            elif "." in item:
                item = item.split(".")[0]
            matches.append(item)
            matching = False
            item = ""
        if matching and x == "}":
            item += x
            matches.append(item)
            matching = False
            item = ""
        if matching:
            item += x

    if matching:
        if " " in item:
            item = item.split(" ")[0]
        elif "." in item:
            item = item.split(".")[0]
        matches.append(item)
    return matches


def find_cookware(step: str) -> list[str]:
    """Find cookware items in a recipe step"""
    return find_specials(step, "#")


def find_ingredients(step: str) -> list[str]:
    """Find ingredients in a recipe step"""
    return find_specials(step, "@")


def find_timers(step: str) -> list[str]:
    """Find timers in a recipe step"""
    return find_specials(step, "~")


class Recipe:
    def __init__(self, file_path: Path):
        if isinstance(file_path, str):
            file_path = Path(file_path)
        self.file_path = file_path
        self.metadata = {}
        self.ingredients = []
        self.cookware = []
        self.timers = []
        self.steps = []
        self.ast = self.parse_ast()

    @property
    def title(self) -> str:
        return self.file_path.stem

    def parse_ast(self) -> dict:
        """Read the file and convert to AST dictionary"""
        with open(self.file_path) as f:
            lines = f.readlines()

        for i, line in enumerate(lines):
            line = line.strip()
            line = line.split("--")[0]  # Remove comments

            if line[0:2] == ">>":  # Metadata line
                key, val = line[2:].split(":", maxsplit=1)
                key = key.strip()
                val = val.strip()
                self.metadata[key] = val
                continue

            if not line:  # Skip empty lines
                continue

            step = line

            step_items = [step]
            cookware_texts = []
            ingredient_texts = []
            timer_texts = []

            for cookware in find_cookware(step):
                cookware_texts.append(cookware)
                item = parse_cookware(cookware)
                self.cookware.append(item)

            for ingredient in find_ingredients(step):
                ingredient_texts.append(ingredient)
                item = parse_ingredient(ingredient)
                self.ingredients.append(item)

            for timer in find_timers(step):
                timer_texts.append(timer)
                item = parse_timer(timer)
                self.timers.append(item)

            things = ingredient_texts + cookware_texts + timer_texts
            for thing in things:
                temp_items = copy.deepcopy(step_items)
                for item in temp_items:
                    item_index = step_items.index(item)
                    if thing in item:
                        before, after = item.split(thing, maxsplit=1)
                        step_items[item_index : item_index + 2] = [
                            before,
                            thing,
                            after,
                        ]

            step_item_dicts = []
            for text in step_items:
                if not text:
                    continue  # Skip empty line
                elif text[0] == "@":
                    item = parse_ingredient(text)
                elif text[0] == "#":
                    item = parse_cookware(text)
                elif text[0] == "~":
                    item = parse_timer(text)
                else:
                    item = {"type": "text", "value": text}
                step_item_dicts.append(item)

            self.steps.append(step_item_dicts)

        return {
            "metadata": self.metadata,
            "ingredients": self.ingredients,
            "cookware": self.cookware,
            "steps": self.steps,
        }

    @property
    def ast_json(self):
        return json.dumps(self.ast, indent=4)
