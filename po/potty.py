import sys

import polib, os

if os.path.exists(os.path.join(sys.argv[1], "aegisub.pot")):
    poba = polib.pofile(os.path.join(sys.argv[1], "aegisub.pot"))
else:
    print("Missing Aegisub.pot")
    sys.exit(1)

for file in os.listdir(sys.argv[1]):
    if file.endswith(".po"):
        pob = polib.pofile(os.path.join(sys.argv[1], file))
        loc = file.split(".")[0]
        os.makedirs(os.path.join(sys.argv[1], "locale", loc, "LC_MESSAGES"), exist_ok=True)
        pob.save_as_mofile(os.path.join(sys.argv[1], "locale", loc, "LC_MESSAGES", "aegisub.mo".replace(".po", ".mo")))
