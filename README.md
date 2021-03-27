# Description

A recipe collection using [nyum](https://github.com/doersino/nyum).

You can find the website [here](https://summit.cooking/).

# Formatting

Extracted from nyum's [README](https://github.com/doersino/nyum/blob/main/README.md).

TL;DR: See the example recipes in `_recipes/`.

Each recipe **begins with YAML front matter specifying its title**, how many servings it produces, whether it's spicy or vegan or a favorite, the category, an image (which must also be located in the `_recipes/` directory), and other information. Most of these are optional!

The **body of a recipe consists of horizontal-rule-separated steps, each listing ingredients relevant in that step along with the associated instruction**. Ingredients are specified as an unordered list, with ingredient amounts enclosed in backticks (this enables the columns on the resulting website – if you don't care about that, omit the backticks). The instructions must be preceded with a `>`. Note that a step can also solely consist of an instruction.

*You've got the full power of Markdown at your disposal – douse your recipes in formatting, include a picture for each step, and use the garlic emoji as liberally as you should be using garlic in your cooking!*

```markdown
---
title: Cheese Buldak
original_title: 치즈불닭
category: Korean Food
description: Super-spicy chicken tempered with loads of cheese and fresh spring onions. Serve with rice and a light salad – or, better yet, an assortment of side dishes.
image: cheesebuldak.jpg
size: 2-3 servings
time: 1 hour
author: Maangchi
source: https://www.youtube.com/watch?v=T9uI1-6Ac6A
spicy: ✓
favorite: ✓
---

* `2 tbsp` chili flakes (gochugaru)
* `1 tbsp` gochujang
* `½-⅔ tbsp` soy sauce
* `1 tbsp` cooking oil
* `¼ tsp` pepper
* `2-3 tbsp` rice or corn syrup
* `2 tbsp` water

> Mix in an oven-proof saucepan or cast-iron skillet – you should end up with a thick marinade.

---

* `3-4 cloves` garlic
* `2 tsp` ginger

> Peel, squish with the side of your knife, then finely mince and add to the marinade.

---

> ⋯ (omitted for brevity)

---

> Garnish with the spring onion slices and serve.

```
