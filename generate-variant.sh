#!/usr/bin/env bash
#
# A utility script to generate and manage custom color variants for the Papirus Icon Theme.
# Compatible with Papirus: https://github.com/PapirusDevelopmentTeam/papirus-icon-theme
#

set -euo pipefail

SUBDIRS=('16x16' '22x22' '24x24' '32x32' '48x48' '64x64')
TARGET_BASE="$HOME/.local/share/icons/Papirus"

if [ ! -d "$TARGET_BASE" ]; then
  TARGET_BASE="/usr/share/icons/Papirus"
fi

SUDO=''
if [[ ! -w $TARGET_BASE ]]; then
  SUDO='sudo'
fi

GENERATE_MODE=true
INSTALL_MODE=false
UNINSTALL_MODE=false

OLD_VARIANT_NAME='blue'
OLD_MAIN_COLOR='5294e2'
OLD_BACK_COLOR='4877b1'
OLD_EMBLEM_COLOR='1d344f'
OLD_DOCUMENT_COLOR='e4e4e4'

NEW_VARIANT_NAME=''
NEW_MAIN_COLOR=''
NEW_BACK_COLOR=''
NEW_EMBLEM_COLOR=''
NEW_DOCUMENT_COLOR='e4e4e4'

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

read_file() {
  {
    IFS= read -r NEW_VARIANT_NAME
    IFS= read -r NEW_MAIN_COLOR
    IFS= read -r NEW_BACK_COLOR
    IFS= read -r NEW_EMBLEM_COLOR
    IFS= read -r NEW_DOCUMENT_COLOR
  } <$1

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
  echo " "
  echo -e "\e[0;34mVariant name\e[0m: \e[0;33m$NEW_VARIANT_NAME\e[0m"
  echo -e "\e[0;34mMain color\e[0m: \e[0;33m$NEW_MAIN_COLOR\e[0m"
  echo -e "\e[0;34mBack color\e[0m: \e[0;33m$NEW_BACK_COLOR\e[0m"
  echo -e "\e[0;34mEmblem color\e[0m: \e[0;33m$NEW_EMBLEM_COLOR\e[0m"
  echo -e "\e[0;34mDocument color\e[0m: \e[0;33m$NEW_DOCUMENT_COLOR\e[0m"
  echo " "
}

recolor_folder_icon() {
  local folder_file=$1
  sed -i \
    -e "s/$OLD_MAIN_COLOR/$NEW_MAIN_COLOR/g" \
    -e "s/$OLD_BACK_COLOR/$NEW_BACK_COLOR/g" \
    -e "s/$OLD_EMBLEM_COLOR/$NEW_EMBLEM_COLOR/g" \
    -e "s/$OLD_DOCUMENT_COLOR/$NEW_DOCUMENT_COLOR/g" \
    "$folder_file"
}

create_new_folder_icon_file() {
  local file="$1" size="$2" target new_target
  local base_file_name=${file##*/}
  local new_file="$NEW_VARIANT_NAME/$size/places/${base_file_name/$OLD_VARIANT_NAME/$NEW_VARIANT_NAME}"

  if [[ -L $file ]]; then
    target=$(readlink "$file")
    new_target=$(echo "$target" | sed "s/$OLD_VARIANT_NAME/$NEW_VARIANT_NAME/g")

    if [[ -L "$new_file" ]]; then
      rm "$new_file"
    fi

    ln -s "$new_target" "$new_file"
  else
    cp "$file" "$new_file"
    recolor_folder_icon "$new_file"
  fi
}

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

if ($INSTALL_MODE && $UNINSTALL_MODE); then
  echo -e "\e[0;31mError\e[0m: Option -u cannot be used with -i" >&2
  exit 1
fi

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

if [[ -d $TARGET_BASE ]]; then
  echo -e "Papirus installation found at \e[0;33m$TARGET_BASE\e[0m"
else
  echo -e "\e[0;31mError\e[0m: Papirus installation not found." >&2
  exit 1
fi

read_file $1

if $GENERATE_MODE; then
  echo -e "\e[0;32mGENERATING COLOR\e[0m"
  mkdir -p "$NEW_VARIANT_NAME"

  for size in "${SUBDIRS[@]}"; do
    cur_dir="$TARGET_BASE/$size/places"

    if [[ -d $cur_dir ]]; then
      echo -e "\e[0;34mProcessing directory\e[0m: $cur_dir"
      mkdir -p "$NEW_VARIANT_NAME/$size/places"

      create_new_folder_icon_file "$cur_dir/folder-$OLD_VARIANT_NAME.svg" $size

      if [[ "$size" == "16x16" ]]; then continue; fi

      for prefix in folder user; do
        for file in "${cur_dir}/${prefix}-${OLD_VARIANT_NAME}-"*.svg; do
          create_new_folder_icon_file $file $size
        done
      done
    fi
  done
fi

if $INSTALL_MODE; then
  if [[ ! -d "$NEW_VARIANT_NAME" ]]; then
    echo -e "\e[0;31mError\e[0m: Variant folder \e[0;33m$NEW_VARIANT_NAME\e[0m not found" >&2
    exit 1
  fi

  echo -e "\e[0;34mInstalling variant: \e[0;33m$NEW_VARIANT_NAME\e[0m"
  $SUDO cp -PR "$NEW_VARIANT_NAME"/* "$TARGET_BASE"
fi

if $UNINSTALL_MODE; then
  echo -e "\e[0;34mUninstalling variant: \e[0;33m$NEW_VARIANT_NAME\e[0m"

  for size in "${SUBDIRS[@]}"; do
    cur_dir="$TARGET_BASE/$size/places"
    if [[ -d $cur_dir ]]; then
      echo -e "\e[0;34mRemoving \e[0;33m$NEW_VARIANT_NAME\e[0;34m icons from directory\e[0m: $cur_dir"
      $SUDO rm -f "${cur_dir}/folder-${NEW_VARIANT_NAME}".svg
      $SUDO rm -f "${cur_dir}/folder-${NEW_VARIANT_NAME}"-*.svg
      $SUDO rm -f "${cur_dir}/user-${NEW_VARIANT_NAME}"-*.svg
    else
      echo "Skipping $cur_dir (directory not found)"
    fi

  done
fi
