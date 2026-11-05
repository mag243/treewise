# dmgbuild settings for the release disk image (ADR 0034). tools/build.sh package
# passes the app and the background:
#   dmgbuild -s tools/dmg/settings.py -D app=<Treewise.app> -D background=<tiff> Treewise <out.dmg>
# The icon places match the arrow in tools/dmg/background.svg.
import os.path

application = defines["app"]  # noqa: F821 (dmgbuild provides `defines`)
app_name = os.path.basename(application)

format = "UDZO"
files = [application]
symlinks = {"Applications": "/Applications"}
hide_extensions = [app_name]

background = defines["background"]  # noqa: F821
window_rect = ((200, 160), (600, 400))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
icon_size = 128
text_size = 13
icon_locations = {app_name: (150, 190), "Applications": (450, 190)}
