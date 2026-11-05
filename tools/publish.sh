#!/usr/bin/env bash
# Publishes the release that tools/build.sh package left in build/release/
# (ADR 0035): adds the zip to the Sparkle appcast (ADR 0032), creates the
# GitHub Release with the zip and the disk image, commits the appcast and the
# download link to the site branch (ADR 0056), and writes the Homebrew cask (ADR 0033).
#
# Usage: tools/publish.sh      (tools/build.sh publish, or the release workflow)
#
# Signs with the Sparkle key in the keychain, or with SPARKLE_PRIVATE_KEY when it
# is set; pushes with the git and gh login it runs under. It pushes to public
# repositories, so only the owner or the release workflow runs it.
set -euo pipefail
# shellcheck source=tools/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

RELEASES_REPOSITORY="mag243/treewise"
SITE_BRANCH="gh-pages"
TAP_REPOSITORY="mag243/homebrew-tap"
WORK="$BUILD_DIR/publish"

# The one file in build/release/ with the extension $1.
release_file() {
  local files=("$BUILD_DIR"/release/*."$1")
  [[ ${#files[@]} == 1 && -f "${files[0]}" ]] \
    || fail "Expected one .$1 in build/release/; run tools/build.sh package first."
  printf '%s\n' "${files[0]}"
}

# Commits all changes of a clone and pushes them; the release workflow commits
# as its bot, the owner as themselves.
commit_and_push() {
  local clone="$1" message="$2"
  if [[ "${CI:-}" == true ]]; then
    git -C "$clone" config user.name "github-actions[bot]"
    git -C "$clone" config user.email "41898282+github-actions[bot]@users.noreply.github.com"
  fi
  git -C "$clone" add -A
  git -C "$clone" commit --quiet -m "$message"
  git -C "$clone" push --quiet
}

# Adds the zip to the site branch's appcast; generate_appcast reuses
# the appcast it finds next to the zip, and the notes with the zip's name
# become the new item's release notes.
update_appcast() {
  local zip="$1" tag="$2" notes="$3" clone="$4"
  local feed="$WORK/appcast"
  mkdir -p "$feed"
  cp "$zip" "$feed/"
  cp "$notes" "$feed/$(basename "$zip" .zip).md"
  [[ -f "$clone/appcast.xml" ]] && cp "$clone/appcast.xml" "$feed/"
  local tool
  tool="$(find "$BUILD_DIR/DerivedData/SourcePackages/artifacts" -path '*/bin/generate_appcast' -type f | head -n 1)"
  [[ -x "$tool" ]] || fail "No generate_appcast in the Sparkle package; run tools/build.sh build first."
  local options=(--download-url-prefix "https://github.com/$RELEASES_REPOSITORY/releases/download/$tag/"
    --embed-release-notes --maximum-versions 10)
  if [[ -n "${SPARKLE_PRIVATE_KEY:-}" ]]; then
    printf '%s' "$SPARKLE_PRIVATE_KEY" | "$tool" --ed-key-file - "${options[@]}" "$feed"
  else
    "$tool" "${options[@]}" "$feed"
  fi
  cp "$feed/appcast.xml" "$clone/appcast.xml"
}

# Points the download page's button at the disk image of this release (ADR 0053):
# GitHub has no stable link to the newest file of a prerelease.
update_download_link() {
  local page="$1" url="$2"
  [[ -f "$page" ]] || return 0
  sed -E "s#(data-download href=\")[^\"]*#\\1$url#" "$page" >"$page.new"
  grep -qF "data-download href=\"$url\"" "$page.new" \
    || fail "$page has no download button to update."
  mv "$page.new" "$page"
}

step "Publish"
zip="$(release_file zip)"
dmg="$(release_file dmg)"
name="$(basename "$zip" .zip)"
[[ "$name" =~ ^$APP_NAME-([0-9]+\.[0-9]+\.[0-9]+)-[0-9.]+$ ]] || fail "$name is not named $APP_NAME-<version>-<build>"
version="${BASH_REMATCH[1]}"
tag="v$version"
! gh release view "$tag" --repo "$RELEASES_REPOSITORY" >/dev/null 2>&1 \
  || fail "$RELEASES_REPOSITORY already has a release $tag."

rm -rf "$WORK"
mkdir -p "$WORK"
"$TOOLS_DIR/release_notes.sh" "$version" >"$WORK/notes.md"
git clone --quiet --depth 1 --branch "$SITE_BRANCH" "https://github.com/$RELEASES_REPOSITORY.git" "$WORK/site"
git clone --quiet --depth 1 "https://github.com/$TAP_REPOSITORY.git" "$WORK/tap"

update_appcast "$zip" "$tag" "$WORK/notes.md" "$WORK/site"
ok "Appcast has $APP_NAME $version"
update_download_link "$WORK/site/index.html" \
  "https://github.com/$RELEASES_REPOSITORY/releases/download/$tag/$(basename "$dmg")"

# The Release comes before the appcast, so the zip exists when Sparkle reads of it.
# --verify-tag: without the tag on GitHub, gh would make one at the newest commit of main.
prerelease=()
[[ "$version" == 0.* ]] && prerelease=(--prerelease)
gh release create "$tag" "$zip" "$dmg" --repo "$RELEASES_REPOSITORY" --verify-tag \
  --title "$APP_NAME $version" --notes-file "$WORK/notes.md" "${prerelease[@]}" >/dev/null
ok "Release $tag in $RELEASES_REPOSITORY"

commit_and_push "$WORK/site" "$APP_NAME $version"
ok "Appcast published"

# The cask comes last, so brew installs only a version that is downloadable and
# in the appcast.
mkdir -p "$WORK/tap/Casks"
"$TOOLS_DIR/homebrew/cask.sh" "$zip" >"$WORK/tap/Casks/treewise.rb"
commit_and_push "$WORK/tap" "treewise $version"
ok "Cask treewise $version in $TAP_REPOSITORY"
