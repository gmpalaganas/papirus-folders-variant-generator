# Papirus Custom Variant Generator

A utility Bash script designed to automatically generate, install, and uninstall custom color variants for the **Papirus Icon Theme**. 

Instead of manually editing SVG color codes across multiple directories and sizes, this script reads a simple configuration file and handles the recoloring and symlink maintenance for you.

---

## Features

- **Automated Recoloring**: Replaces hex color codes for the various parts of the folder icons (front, back flap, emblem, and document) across multiple icon sizes (`16x16` up to `64x64`).
- **Symlink Handling**: Correctly processes both standard SVG files and symbolic links (such as folder redirects).
- **Flexible Modes**: Generate variant folders locally, install them directly to your **Papirus Icon Theme** installation, or cleanly uninstall them when no longer needed.

---

## Requirements

- Bash (version 4+)
- Standard core utilities (`sed`, `cp`, `rm`, `ln`, `mkdir`)
- An existing installation of the [Papirus Icon Theme](https://github.com/PapirusDevelopmentTeam/papirus-icon-theme)

---

## Configuration File Format

To generate a new variant, create a plain text file (e.g., `my_variant.txt`) containing 5 lines in the exact order below:

1. **Variant name** (alphanumeric, underscores, hyphens, or periods only)
2. **Main color** (6-digit hex code without `#`, e.g., `5294e2`)
3. **Back flap color** (6-digit hex code)
4. **Emblem color** (6-digit hex code)
5. **Document color** (6-digit hex code)

### Example Configuration (`my_variant.txt`)
```text
mycolor
ff5733
c70039
900c3f
e4e4e4

```

---

## Usage

```bash
$./generate-variant.sh [OPTIONS] variant_file

```

### Options

* `-h` : Display help message and exit.


* `-i` : Install the generated variant icons into the system Papirus directory (`/usr/share/icons/Papirus`). Requires `sudo`.


* `-u` : Uninstall the specified variant icons from the system Papirus directory. Requires `sudo`.


* `-n` : Skip generation mode (useful if the variant is already generated and you only want to install).



### Examples

**Generate a new variant locally:**

```bash
./generate-variant.sh my_variant.txt

```

**Generate and install the variant system-wide:**

```bash
sudo ./generate-variant.sh -i my_variant.txt

```

**Uninstall an existing variant:**

```bash
sudo ./generate-variant.sh -u my_variant.txt

```

---

## Credits & Acknowledgements

* This script is designed to work with the [Papirus Icon Theme](https://github.com/PapirusDevelopmentTeam/papirus-icon-theme), which is licensed under the **GNU General Public License v3.0 (GPLv3)**.

---

## License

This project is licensed under the **MIT License** - see the [LICENSE](https://www.google.com/search?q=LICENSE) file for details.
