#!/usr/bin/env python3
"""Fills zContainer's Home Screen in the iOS Simulator with placeholder apps and
folders, laid out like a new iPhone's, to compare it with the real SpringBoard
and to try paging, folders and editing. It also skips onboarding.

The apps are only names and icons, with no executable, so opening one fails.
Those the Simulator has keep its Info.plist and icons, so they show the real
iOS icons, dark and tinted ones included. The rest take the icon of the Mac app
of the same name, which mac-app-icon.swift turns into iOS icon files.

usage: Scripts/simulator/seed-home-screen.py [device]
  device               a simulator's UDID or name; the booted one by default
  ZC_SIM_BUNDLE_ID     zContainer's bundle ID (app.reiko.zcontainer.AAAAA11111)

Running it again replaces the placeholders and the layout; other apps stay.
"""

import json
import os
import plistlib
import shutil
import subprocess
import sys
import tempfile

DEVICE = sys.argv[1] if len(sys.argv) > 1 else "booted"
BUNDLE_ID = os.environ.get("ZC_SIM_BUNDLE_ID", "app.reiko.zcontainer.AAAAA11111")
HERE = os.path.dirname(os.path.abspath(__file__))
# Left in each placeholder, so a second run knows which apps are its own.
MARKER = ".zc-placeholder"

# The Simulator's own apps, by bundle ID, with the name each shows.
SIMULATOR_APPS = {
    "com.apple.mobilesafari": "Safari",
    "com.apple.MobileSMS": "Messages",
    "com.apple.mobilecal": "Calendar",
    "com.apple.mobileslideshow": "Photos",
    "com.apple.news": "News",
    "com.apple.Maps": "Maps",
    "com.apple.Health": "Health",
    "com.apple.Passbook": "Wallet",
    "com.apple.reminders": "Reminders",
    "com.apple.Fitness": "Fitness",
    "com.apple.MobileAddressBook": "Contacts",
    "com.apple.DocumentsApp": "Files",
    "com.apple.Passwords": "Passwords",
    "com.apple.Preview": "Preview",
    "com.apple.shortcuts": "Shortcuts",
    "com.apple.Bridge": "Watch",
}

# Apps the Simulator lacks: bundle ID, name, and the Mac app whose icon they take.
MAC_APPS = {
    "com.apple.mobilephone": ("Phone", "Phone"),
    "com.apple.Music": ("Music", "Music"),
    "com.apple.facetime": ("FaceTime", "FaceTime"),
    "com.apple.mobilemail": ("Mail", "Mail"),
    "com.apple.mobilenotes": ("Notes", "Notes"),
    "com.apple.mobiletimer": ("Clock", "Clock"),
    "com.apple.tv": ("TV", "TV"),
    "com.apple.podcasts": ("Podcasts", "Podcasts"),
    "com.apple.AppStore": ("App Store", "App Store"),
    "com.apple.weather": ("Weather", "Weather"),
    "com.apple.iBooks": ("Books", "Books"),
    "com.apple.stocks": ("Stocks", "Stocks"),
    "com.apple.Home": ("Home", "Home"),
    "com.apple.journal": ("Journal", "Journal"),
    "com.apple.games": ("Games", "Games"),
    "com.apple.calculator": ("Calculator", "Calculator"),
    "com.apple.VoiceMemos": ("Voice Memos", "VoiceMemos"),
    "com.apple.findmy": ("Find My", "FindMy"),
    "com.apple.tips": ("Tips", "Tips"),
    "com.apple.freeform": ("Freeform", "Freeform"),
    "com.apple.GenerativePlaygroundApp": ("Image Playground", "Image Playground"),
}

# Where everything goes, by name. "Settings" is zContainer's own Settings.
DOCK = ["Phone", "Safari", "Messages", "Music"]
PAGES = [
    ["FaceTime", "Calendar", "Photos", "Mail",
     "Notes", "Reminders", "Clock", "News",
     "TV", "Podcasts", "App Store", "Maps",
     "Health", "Wallet", "Weather", "Settings"],
    ["Books", "Stocks", "Home", "Journal",
     "Fitness", "Games", "folder:Utilities", "folder:Creativity"],
]
# The widgets iOS 26.5's Home Screen starts with at the top of its first page,
# as (size, the widgets in it), a stack when there are several.
PHONE_WIDGETS = [("small", ["maps"]), ("small", ["calendar", "news", "photos"])]
PAD_WIDGETS = [("large", ["news", "maps", "photos"]), ("large", ["reminders"]), ("medium", ["calendar"]),
               ("large", ["calendar"]), ("medium", ["maps"])]
# Utilities holds more than nine, so it has two pages.
FOLDERS = {
    "Utilities": ["Calculator", "Voice Memos", "Contacts", "Find My", "Watch",
                  "Tips", "Passwords", "Files", "Preview", "Shortcuts"],
    "Creativity": ["Freeform", "Image Playground"],
}


def run(*args, **kwargs):
    return subprocess.run(args, check=True, capture_output=True, text=True, **kwargs).stdout.strip()


def simctl(*args, **kwargs):
    return run("xcrun", "simctl", *args, **kwargs)


def bundle_folder(name):
    return f"{name}.app"


def copy_simulator_app(source, name, destination):
    """The app's Info.plist, asset catalog and icon files, under `name`."""
    os.makedirs(destination)
    with open(os.path.join(source, "Info.plist"), "rb") as file:
        info = plistlib.load(file)
    info["CFBundleDisplayName"] = name
    with open(os.path.join(destination, "Info.plist"), "wb") as file:
        plistlib.dump(info, file)
    for entry in os.listdir(source):
        if entry == "Assets.car" or (entry.startswith("AppIcon") and entry.endswith(".png")):
            shutil.copy(os.path.join(source, entry), destination)


def make_mac_app(tool, bundle_id, name, mac_app, destination):
    """An Info.plist naming the icon files, and the Mac app's icon as them."""
    os.makedirs(destination)
    run(tool, f"/System/Applications/{mac_app}.app", destination, "AppIcon")
    os.remove(os.path.join(destination, "AppIcon1024x1024.png"))
    executable = name.replace(" ", "")
    info = {
        "CFBundleIdentifier": bundle_id,
        "CFBundleName": name,
        "CFBundleDisplayName": name,
        "CFBundleExecutable": executable,
        "CFBundlePackageType": "APPL",
        "CFBundleShortVersionString": "26.0",
        "CFBundleVersion": "1",
        "CFBundleSupportedPlatforms": ["iPhoneOS"],
        "MinimumOSVersion": "17.0",
        "UIDeviceFamily": [1, 2],
        "CFBundleIcons": {"CFBundlePrimaryIcon": {"CFBundleIconFiles": ["AppIcon60x60"]}},
        "CFBundleIcons~ipad": {"CFBundlePrimaryIcon": {
            "CFBundleIconFiles": ["AppIcon60x60", "AppIcon76x76", "AppIcon83.5x83.5"]}},
    }
    with open(os.path.join(destination, "Info.plist"), "wb") as file:
        plistlib.dump(info, file)


def is_pad():
    devices = json.loads(simctl("list", "devices", "--json"))["devices"]
    for runtime in devices.values():
        for device in runtime:
            if device["udid"] == DEVICE or (DEVICE == "booted" and device["state"] == "Booted"):
                return "iPad" in device["name"]
    return False


def main():
    data = simctl("get_app_container", DEVICE, BUNDLE_ID, "data")
    applications = os.path.join(data, "Documents", "Applications")
    os.makedirs(applications, exist_ok=True)
    # zContainer saves its layout when it quits, which would undo this one.
    subprocess.run(["xcrun", "simctl", "terminate", DEVICE, BUNDLE_ID], capture_output=True)

    for entry in os.listdir(applications):
        if os.path.exists(os.path.join(applications, entry, MARKER)):
            shutil.rmtree(os.path.join(applications, entry))

    installed = json.loads(run("plutil", "-convert", "json", "-o", "-", "-",
                               input=simctl("listapps", DEVICE)))
    keys = {}
    for bundle_id, name in SIMULATOR_APPS.items():
        app = installed.get(bundle_id)
        if not app:
            print(f"skipping {name}: not in this Simulator")
            continue
        destination = os.path.join(applications, bundle_folder(name))
        copy_simulator_app(app["Path"], name, destination)
        keys[name] = f"app:{bundle_id}:{bundle_folder(name)}"

    with tempfile.TemporaryDirectory() as temporary:
        tool = os.path.join(temporary, "mac-app-icon")
        run("xcrun", "swiftc", "-O", os.path.join(HERE, "mac-app-icon.swift"), "-o", tool)
        for bundle_id, (name, mac_app) in MAC_APPS.items():
            if not os.path.exists(f"/System/Applications/{mac_app}.app"):
                print(f"skipping {name}: this Mac has no {mac_app}")
                continue
            make_mac_app(tool, bundle_id, name, mac_app, os.path.join(applications, bundle_folder(name)))
            keys[name] = f"app:{bundle_id}:{bundle_folder(name)}"

    for name in keys:
        open(os.path.join(applications, bundle_folder(name), MARKER), "w").close()
    keys["Settings"] = "settings"

    def item(name):
        if name.startswith("folder:"):
            return "folder:placeholder-" + name[len("folder:"):].lower()
        return keys.get(name)

    widgets = PAD_WIDGETS if is_pad() else PHONE_WIDGETS
    pages = [[i for i in map(item, page) if i] for page in PAGES]
    pages[0] = [f"widget:placeholder-widget-{n}" for n in range(len(widgets))] + pages[0]
    layout = {
        "pages": pages,
        "dock": [i for i in map(item, DOCK) if i],
        "folders": {
            "placeholder-" + name.lower(): {"name": name, "items": [i for i in map(item, items) if i]}
            for name, items in FOLDERS.items()
        },
        "widgets": {
            f"placeholder-widget-{n}": {"size": size, "kinds": kinds}
            for n, (size, kinds) in enumerate(widgets)
        },
    }
    # Without an app group, which the Simulator build has none of, the layout
    # is kept in the "Unknown" suite of zContainer's own preferences.
    preferences = os.path.join(data, "Library", "Preferences")
    encoded = json.dumps(layout, separators=(",", ":")).encode().hex()
    simctl("spawn", DEVICE, "defaults", "write", os.path.join(preferences, "Unknown"),
           "ZCHomeScreenLayout", "-data", encoded)
    simctl("spawn", DEVICE, "defaults", "write", os.path.join(preferences, BUNDLE_ID),
           "ZCHasCompletedOnboarding", "-bool", "YES")
    print(f"{len(keys) - 1} placeholder apps, {len(FOLDERS)} folders and {len(widgets)} widgets in {applications}")


if __name__ == "__main__":
    main()
