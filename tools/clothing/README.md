# Clothing templates (optional)

The game already looks finished without anything in this folder. Every outfit is built in 3D from
Parts (jacket, lapels, buttons, trousers, shoes and so on). These tools add an extra layer of printed
detail underneath: classic Roblox **Shirt** and **Pants** images with seams, pockets, stitching and
patterns that match each item.

You only need this if you want that extra detail. Skip it and nothing breaks.

## What's here

| File | What it does |
|---|---|
| `generate.py` | Paints one 585 x 559 template image for every top, jacket and bottom in the wardrobe catalogue and saves them in `assets/clothing/`. |
| `paint.py` | The drawing helpers `generate.py` uses (template layout, colours, fabric patterns). |
| `upload.py` | Uploads those images to your Roblox account and writes their ids into `src/shared/Config/ClothingIds.luau`. |
| `export.luau` | Reads the catalogue for the two Python scripts. You never run it yourself. |

The images are already generated and saved in `assets/clothing/` (one `<item>_shirt.png` or
`<item>_pants.png` per item), so you can go straight to uploading.

## What you need

- Python 3 (any recent version).
- Pillow, only to repaint the images: `pip install pillow`.
- Lune, which the project already uses (`tools/setup.sh` installs it).

Run every command from the top folder of the project.

## Repaint the images (only after you change the catalogue)

```
python3 tools/clothing/generate.py
```

Useful options:

- `--only oxford_white suit_navy_2b` repaints just those items.
- `--sheet sheet.png` also saves one big picture with every template side by side, so you can check
  them at a glance.
- `--clean` deletes images of items that are no longer in the catalogue.

The same catalogue always produces exactly the same images.

## Upload them to Roblox

1. Create an **Open Cloud API key** at <https://create.roblox.com/dashboard/credentials>.
   Give it the **Assets** API with the `asset:read` and `asset:write` permissions. Also add
   `legacy-asset:manage` if it's offered (the script uses it to look up each image's id).
   Under "Accepted IP addresses" you can add `0.0.0.0/0` while you upload, then remove it.
2. Find your **user id**: it's the number in the address of your Roblox profile page.
   (To upload to a group instead, use the group's id and add `--group`.)
3. Run:

```
export ROBLOX_API_KEY=paste-your-key-here
export ROBLOX_CREATOR_ID=your-user-id
python3 tools/clothing/upload.py
```

On Windows PowerShell use `$env:ROBLOX_API_KEY="..."` and `$env:ROBLOX_CREATOR_ID="..."` instead of
`export`.

The script uploads each image, waits for Roblox to process it, and writes its id into
`src/shared/Config/ClothingIds.luau` as it goes. It remembers what it already uploaded in
`assets/clothing/uploads.json`, so running it again only uploads images that changed. Roblox moderates
uploads, so a few may take a while to appear in game.

Other options:

- `--dry-run` lists what would be uploaded without uploading anything.
- `--only oxford_white` uploads just that item.
- `--force` uploads again even when an image didn't change.
- `--init` rewrites `ClothingIds.luau` with every id set back to 0 (turns the templates off).

## If something goes wrong

- **"uploaded as decal ..., but its image id isn't readable yet"**: Roblox is still processing it.
  Run the script again in a few minutes; it only retries the ones that need it. You can also open the
  decal in Studio, copy its image id and paste it into `ClothingIds.luau` in place of the `0`.
- **HTTP 401 or 403**: the key is wrong, expired, missing a permission, or blocked by its IP list.
- **"Couldn't run 'lune run tools/clothing/export'"**: install Lune with `tools/setup.sh`, or run from
  the top folder of the project.

## How the game uses the ids

When an item has an id in `ClothingIds.luau`, the server puts a Shirt or Pants with that image on the
player underneath the 3D outfit. An id of `0` means "not uploaded", and the 3D outfit is shown on its
own. Nothing else needs to change.
