#!/usr/bin/env bash
#
# A utility script to generate and manage custom color variants for the Papirus Icon Theme.
# Compatible with Papirus: https://github.com/PapirusDevelopmentTeam/papirus-icon-theme
#
# How it works:
#   1. GENERATE: copies the stock "blue" folder/user icons from an installed Papirus theme
#      into a local ./<variant name>/ directory, renames them, and swaps the four blue
#      colors for the colors given in the variant config file.
#   2. INSTALL:  copies the generated ./<variant name>/ directory into the Papirus theme.
#   3. UNINSTALL: removes the variant's icons from the Papirus theme.
#
# Requirements: bash 4+ (uses ${var,,}), GNU sed (uses -i without a suffix, \b, and the I flag).
#

# Exit on any error (-e), on unset variables (-u), and on failures inside pipes (pipefail).
set -euo pipefail

# Icon size directories to process inside the Papirus theme.
SUBDIRS=('16x16' '22x22' '24x24' '32x32' '48x48' '64x64')

# Prefer the per-user Papirus install, fall back to the system-wide one.
TARGET_BASE="$HOME/.local/share/icons/Papirus"

if [ ! -d "$TARGET_BASE" ]; then
  TARGET_BASE="/usr/share/icons/Papirus"
fi

# Use sudo for write operations only when the target is not writable by the current user.
SUDO=''
if [[ ! -w $TARGET_BASE ]]; then
  SUDO='sudo'
fi

# Mode flags, set by command-line options.
GENERATE_MODE=true
INSTALL_MODE=false
UNINSTALL_MODE=false

# The stock variant used as the template, and the colors inside its SVGs
# that get replaced (hex values without the leading '#').
OLD_VARIANT_NAME='blue'
OLD_MAIN_COLOR='5294e2'
OLD_BACK_COLOR='4877b1'
OLD_EMBLEM_COLOR='1d344f'
OLD_DOCUMENT_COLOR='e4e4e4'

# Values for the new variant, filled in by read_file() from the config file.
NEW_VARIANT_NAME=''
NEW_MAIN_COLOR=''
NEW_BACK_COLOR=''
NEW_EMBLEM_COLOR=''
NEW_DOCUMENT_COLOR='e4e4e4'

# Print usage information.
print_help() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS] variant_file

A script to generate, install, or uninstall custom color variants for the Papirus icon theme.

OPTIONS:
  -h        Display this help message and exit
  -i        Install the generated variant icons into the Papirus icon theme install directory (~/.local/share/icons/Papirus by default)
  -u        Uninstall the specified variant icons from the Papirus icon theme install directory
  -n        Skip generation mode (useful if the variant is already generated and you only want to install)

ARGUMENTS:
  variant_file   A text file containing the configuration for the new variant with the following format line-by-line:
                 1. Variant name
                 2. Main color (Hex code, e.g., 5294e2)
                 3. Background color (Hex code)
                 4. Emblem color (Hex code)
                 5. Document color (Hex code)

EXAMPLES:
  # Generate a new variant based on a config file
  $(basename "$0") my_custom_variant.txt

  # Generate and install the variant
  $(basename "$0") -i my_custom_variant.txt

  # Uninstall an existing variant
  $(basename "$0") -u my_custom_variant.txt
EOF
}

# Read and validate the variant config file (path passed as $1).
# Populates the NEW_* globals, exits with an error on invalid input,
# and prints a summary of the parsed values.
#
# NOTE: because of 'set -e', a config file without a trailing newline makes the
# last 'read' return non-zero and the script exits silently. End the file with a newline.
read_file() {
  # Read the five config lines in order, without trimming or backslash processing.
  {
    IFS= read -r NEW_VARIANT_NAME
    IFS= read -r NEW_MAIN_COLOR
    IFS= read -r NEW_BACK_COLOR
    IFS= read -r NEW_EMBLEM_COLOR
    IFS= read -r NEW_DOCUMENT_COLOR
  } <"$1"

  # Refuse stock Papirus variant names so install/uninstall can never
  # overwrite or delete the theme's built-in icons.
  # (Verify this list against your install:
  #  ls "$TARGET_BASE/48x48/places/" | grep '^folder-[a-z]*\.svg')
  case "${NEW_VARIANT_NAME,,}" in
  adwaita | black | blue | bluegrey | breeze | brown | carmine | cyan | darkcyan | deeporange | green | grey | indigo | magenta | nordic | orange | palebrown | paleorange | pink | red | teal | violet | white | yaru | yellow)
    echo -e "\e[0;31mError\e[0m: \e[0;33m$NEW_VARIANT_NAME\e[0m is a stock Papirus variant name" >&2
    exit 1
    ;;
  esac

  # Allowed characters for the variant name (used in directory and file names)
  # and the exact format of a color (six hex digits, no '#').
  local filename_part_regex='^[a-zA-Z0-9_ .-]+$'
  local hex_color_regex='^([0-9a-fA-F]{6})$'

  if [[ ! "$NEW_VARIANT_NAME" =~ $filename_part_regex ]]; then
    echo -e "\e[0;31mError\e[0m: \e[0;33m$NEW_VARIANT_NAME\e[0m is not a valid filename component" >&2
    exit 1
  fi

  if [[ ! "$NEW_MAIN_COLOR" =~ $hex_color_regex ]]; then
    echo -e "\e[0;31mError\e[0m: \e[0;33m$NEW_MAIN_COLOR\e[0m is not a valid color hex code" >&2
    exit 1
  fi

  if [[ ! "$NEW_BACK_COLOR" =~ $hex_color_regex ]]; then
    echo -e "\e[0;31mError\e[0m: \e[0;33m$NEW_BACK_COLOR\e[0m is not a valid color hex code" >&2
    exit 1
  fi

  if [[ ! "$NEW_EMBLEM_COLOR" =~ $hex_color_regex ]]; then
    echo -e "\e[0;31mError\e[0m: \e[0;33m$NEW_EMBLEM_COLOR\e[0m is not a valid color hex code" >&2
    exit 1
  fi

  if [[ ! "$NEW_DOCUMENT_COLOR" =~ $hex_color_regex ]]; then
    echo -e "\e[0;31mError\e[0m: \e[0;33m$NEW_DOCUMENT_COLOR\e[0m is not a valid color hex code" >&2
    exit 1
  fi

  # Show the parsed configuration.
  echo " "
  echo -e "\e[0;34mVariant name\e[0m: \e[0;33m$NEW_VARIANT_NAME\e[0m"
  echo -e "\e[0;34mMain color\e[0m: \e[0;33m$NEW_MAIN_COLOR\e[0m"
  echo -e "\e[0;34mBack color\e[0m: \e[0;33m$NEW_BACK_COLOR\e[0m"
  echo -e "\e[0;34mEmblem color\e[0m: \e[0;33m$NEW_EMBLEM_COLOR\e[0m"
  echo -e "\e[0;34mDocument color\e[0m: \e[0;33m$NEW_DOCUMENT_COLOR\e[0m"
  echo " "
}

# Replace the old (blue) colors with the new colors, in place, in one SVG file.
#
# Replacement is done in two stages within a single sed run:
#   1. each old color becomes a unique placeholder, then
#   2. each placeholder becomes the new color.
# This prevents a new color that equals another old color from being replaced twice.
# Matching is anchored on '#', case-insensitive (I flag), and ends at a word boundary (\b)
# so longer hex strings (e.g. #rrggbbaa) are not partially matched.
#
# Arguments:
#   $1  path to the SVG file to modify
recolor_folder_icon() {
  local folder_file=$1

  sed -i \
    -e "s/#$OLD_MAIN_COLOR\b/@@MAIN@@/gI" \
    -e "s/#$OLD_BACK_COLOR\b/@@BACK@@/gI" \
    -e "s/#$OLD_EMBLEM_COLOR\b/@@EMBLEM@@/gI" \
    -e "s/#$OLD_DOCUMENT_COLOR\b/@@DOC@@/gI" \
    -e "s/@@MAIN@@/#$NEW_MAIN_COLOR/g" \
    -e "s/@@BACK@@/#$NEW_BACK_COLOR/g" \
    -e "s/@@EMBLEM@@/#$NEW_EMBLEM_COLOR/g" \
    -e "s/@@DOC@@/#$NEW_DOCUMENT_COLOR/g" \
    "$folder_file"
}

# Create the new variant's version of one stock icon file.
#   - Symlinks are recreated as symlinks, with '-blue' in the target renamed to the new variant.
#   - Regular files are copied and then recolored.
# The output goes to ./<variant name>/<size>/places/, with 'blue' in the file name
# replaced by the new variant name.
#
# Arguments:
#   $1  path to the stock icon file (file or symlink)
#   $2  icon size directory name (e.g. 48x48)
create_new_folder_icon_file() {
  local file="$1" size="$2" target new_target
  local base_file_name="${file##*/}"
  local new_file="$NEW_VARIANT_NAME/$size/places/${base_file_name/$OLD_VARIANT_NAME/$NEW_VARIANT_NAME}"

  if [[ -L "$file" ]]; then
    # Keep the symlink structure, pointing at the renamed variant files.
    target=$(readlink "$file")
    new_target=$(echo "$target" | sed "s/-$OLD_VARIANT_NAME/-$NEW_VARIANT_NAME/g")

    # Remove a stale symlink from a previous run so 'ln -s' doesn't fail.
    if [[ -L "$new_file" ]]; then
      rm "$new_file"
    fi

    ln -s "$new_target" "$new_file"
  else
    # Regular SVG: copy it, then swap the colors.
    cp "$file" "$new_file"
    recolor_folder_icon "$new_file"
  fi
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

# Options: -n skip generation, -i install, -u uninstall (implies no generation), -h help.
while getopts "niuh" flag; do
  case "${flag}" in
  n)
    GENERATE_MODE=false
    ;;
  i)
    INSTALL_MODE=true
    ;;
  u)
    UNINSTALL_MODE=true
    GENERATE_MODE=false
    ;;
  h)
    print_help
    exit 0
    ;;
  *)
    print_help
    exit 1
    ;;
  esac
done

# Installing and uninstalling in the same run makes no sense.
if ($INSTALL_MODE && $UNINSTALL_MODE); then
  echo -e "\e[0;31mError\e[0m: Option -u cannot be used with -i" >&2
  exit 1
fi

# Drop the parsed options; exactly one positional argument (the config file) must remain.
shift $((OPTIND - 1))

if [[ "$#" -ne 1 ]]; then
  echo -e "\e[0;31mError\e[0m: Invalid number of arguments" >&2
  print_help
  exit 1
fi

if [[ ! -f $1 ]]; then
  echo -e "\e[0;31mError\e[0m: File \e[0;33m$1\e[0m not found" >&2
  exit 1
fi

# Make sure there is a Papirus theme to read from / write to.
if [[ -d $TARGET_BASE ]]; then
  echo -e "Papirus installation found at \e[0;33m$TARGET_BASE\e[0m"
else
  echo -e "\e[0;31mError\e[0m: Papirus installation not found." >&2
  exit 1
fi

# Load and validate the variant configuration.
read_file "$1"

# ---------------------------------------------------------------------------
# Generate: build ./<variant name>/ from the stock blue icons
# ---------------------------------------------------------------------------
if $GENERATE_MODE; then
  echo -e "\e[0;32mGENERATING COLOR\e[0m"
  mkdir -p "$NEW_VARIANT_NAME"

  for size in "${SUBDIRS[@]}"; do
    cur_dir="$TARGET_BASE/$size/places"

    # Skip sizes the installed theme doesn't have.
    if [[ -d $cur_dir ]]; then
      echo -e "\e[0;34mProcessing directory\e[0m: $cur_dir"
      mkdir -p "$NEW_VARIANT_NAME/$size/places"

      # The main folder icon exists at every size.
      create_new_folder_icon_file "$cur_dir/folder-$OLD_VARIANT_NAME.svg" "$size"

      # 16x16 only has the main folder icon; skip the extra folder-*/user-* icons.
      if [[ "$size" == "16x16" ]]; then continue; fi

      # Process the folder-blue-*.svg and user-blue-*.svg icons (e.g. folder-blue-documents.svg).
      # NOTE: with 'set -e', a glob that matches nothing is passed literally and makes cp fail.
      for prefix in folder user; do
        for file in "${cur_dir}/${prefix}-${OLD_VARIANT_NAME}-"*.svg; do
          create_new_folder_icon_file "$file" "$size"
        done
      done
    fi
  done
fi

# ---------------------------------------------------------------------------
# Install: copy ./<variant name>/ into the Papirus theme
# ---------------------------------------------------------------------------
if $INSTALL_MODE; then
  if [[ ! -d "$NEW_VARIANT_NAME" ]]; then
    echo -e "\e[0;31mError\e[0m: Variant folder \e[0;33m$NEW_VARIANT_NAME\e[0m not found" >&2
    exit 1
  fi

  echo -e "\e[0;34mInstalling variant: \e[0;33m$NEW_VARIANT_NAME\e[0m"
  # -P keeps symlinks as symlinks, -R copies recursively.
  $SUDO cp -PR "$NEW_VARIANT_NAME"/* "$TARGET_BASE"
fi

# ---------------------------------------------------------------------------
# Uninstall: remove the variant's icons from the Papirus theme
# ---------------------------------------------------------------------------
if $UNINSTALL_MODE; then
  echo -e "\e[0;34mUninstalling variant: \e[0;33m$NEW_VARIANT_NAME\e[0m"

  for size in "${SUBDIRS[@]}"; do
    cur_dir="$TARGET_BASE/$size/places"
    if [[ -d $cur_dir ]]; then
      echo -e "\e[0;34mRemoving \e[0;33m$NEW_VARIANT_NAME\e[0;34m icons from directory\e[0m: $cur_dir"
      # Exact main icon, then the folder-<name>-*.svg and user-<name>-*.svg families.
      # The trailing '-' keeps the globs from matching other variants whose names
      # merely start with this one.
      $SUDO rm -f "${cur_dir}/folder-${NEW_VARIANT_NAME}".svg
      $SUDO rm -f "${cur_dir}/folder-${NEW_VARIANT_NAME}"-*.svg
      $SUDO rm -f "${cur_dir}/user-${NEW_VARIANT_NAME}"-*.svg
    else
      echo "Skipping $cur_dir (directory not found)"
    fi

  done
fi
