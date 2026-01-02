# Immich Better Stacking

A Ruby script that analyzes an Immich server's full asset catalog and automatically stacks related assets together based on configurable criteria.

## Features

- **Automated Stacking**: Automatically groups and stacks assets (e.g., RAW + JPEG, Edits + Originals).
- **Configurable Logic**: Use Regular Expressions to define inclusion, grouping criteria, and parent selection.
- **Dry Run Mode**: Preview stacking operations without making any changes to your Immich server.
- **Smart Stacking**: Skips assets that are already part of a stack.

## Installation

1. Ensure you have Ruby installed.
2. Clone this repository.
3. Install dependencies:
   ```bash
   bundle install
   ```

## Configuration

### Environment Variables

Create a `vars.env` file or set the following environment variables:

- `API_KEY`: Your Immich API key.
- `API_ENDPOINT`: Your Immich server API endpoint (e.g., `https://immich.home.example.com/api`).
- `DRY_RUN`: Set to `true` or `1` to preview changes without applying them (default: `false`).
- `CONFIG_PATH`: Path to your JSON configuration file (default: `config.json`).
- `VARS_PATH`: Path to your environment variables file (default: `vars.env`).

### JSON Configuration (`config.json`)

The configuration file defines one or more "groupings". Each grouping contains:

- `inclusion_operations`: Filters identifying which files are considered for stacking. All operations must match.
- `criteria_operations`: Operations used to generate a "grouping key". Assets with the same key are stacked together.
- `parent_operations`: Operations identifying which file in a group becomes the "parent". The first asset to match any operation wins. If none match, the last asset in the group is chosen.

#### Example

```json
{
  "groupings": [
    {
      "inclusion_operations": [
        { "field": "extension", "pattern": "^(jpe?g|CR2)$" }
      ],
      "criteria_operations": [
        { "field": "filename", "pattern": "^(.*)(_edit)?\\.", "index": 1 },
        { "field": "directory" }
      ],
      "parent_operations": [
        { "field": "filename", "pattern": "_edit\\." }
      ]
    }
  ]
}
```

## Usage

Run the script using the provided executable:

```bash
./bin/stack
```

## Operations

An operation takes a `field` and evaluates it. Optionally, a `pattern` (Regex) can be used to extract a specific part of the field value using an `index` (default: 0).

Available fields:
- `directory`
- `filename`
- `extension`
- `exif_date` (DateTimeOriginal from Immich)
- `original_path`
