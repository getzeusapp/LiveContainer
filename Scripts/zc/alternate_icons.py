#!/usr/bin/env python3
"""Adds the icons Settings > Appearance offers instead of zContainer's own to an
app built with Xcode, as Scripts/zc/assemble.py adds them to the Linux build:
the PNGs Scripts/zc/art/render-icon.sh renders into Resources/AppIcons, copied
into the app's root, and each one listed under CFBundleAlternateIcons by name.
Without them the picker shows blank tiles and iOS can't switch icons.

The LiveContainer target's Run Script phase runs it:

  alternate_icons.py <app> <Info.plist>
"""

import os
import plistlib
import re
import shutil
import sys

ALTERNATE_ICONS = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'Resources', 'AppIcons')


def alternate_icon_names():
    """The name iOS switches to for each icon, like OG for AppIconOG60x60@2x.png."""
    if not os.path.isdir(ALTERNATE_ICONS):
        return []
    found = (re.fullmatch(r'AppIcon(\w+)60x60@2x\.png', f) for f in os.listdir(ALTERNATE_ICONS))
    return sorted({m.group(1) for m in found if m})


def main(app, info_path):
    names = alternate_icon_names()
    if not names:
        return
    for name in sorted(os.listdir(ALTERNATE_ICONS)):
        if name.endswith('.png'):
            shutil.copyfile(os.path.join(ALTERNATE_ICONS, name), os.path.join(app, name))

    with open(info_path, 'rb') as file:
        info = plistlib.load(file)
    # Next to the alternate icons actool lists, such as the grey one.
    phone = info.setdefault('CFBundleIcons', {}).setdefault('CFBundleAlternateIcons', {})
    pad = info.setdefault('CFBundleIcons~ipad', {}).setdefault('CFBundleAlternateIcons', {})
    for name in names:
        phone[name] = {'CFBundleIconFiles': [f'AppIcon{name}60x60']}
        pad[name] = {'CFBundleIconFiles': [f'AppIcon{name}60x60', f'AppIcon{name}76x76', f'AppIcon{name}83.5x83.5']}
    with open(info_path, 'wb') as file:
        plistlib.dump(info, file, fmt=plistlib.FMT_BINARY)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
