# Immich Better Stacking - Implementation Plan

## Overview

A Ruby application that analyzes an Immich server's full asset catalog and automatically stacks related assets together based on configurable criteria.

## Architecture

### File Structure

```
immich-better-stacking/
├── Gemfile                           # Dependencies: faraday, dotenv, json
├── Gemfile.lock
├── bin/
│   └── stack                         # Executable entry point
├── lib/
│   ├── immich_stacker.rb             # Main module, requires all components
│   └── immich_stacker/
│       ├── configuration.rb          # Environment variables & JSON config loading
│       ├── api_client.rb             # Faraday-based Immich API client
│       ├── asset.rb                  # Asset model with parsed fields
│       ├── operation.rb              # Operation evaluation logic
│       ├── grouping.rb               # Grouping configuration wrapper
│       └── stacker.rb                # Main stacking orchestration
├── config.json                       # Configuration file (groupings array)
└── README.md                         # Usage documentation
```

## Component Details

### 1. Gemfile

**Dependencies:**
- `faraday` (~> 2.0) - HTTP client for Immich API
- `faraday-retry` - Retry middleware for resilience
- `dotenv` (~> 2.8) - Environment variable loading (optional, for development)
- `json` - JSON parsing (stdlib)

### 2. bin/stack

Executable entry point that:
- Loads dependencies via Bundler
- Requires the main library
- Calls `ImmichStacker.run`

### 3. lib/immich_stacker.rb

Main module that:
- Requires all component files
- Exposes `ImmichStacker.run` method
- Handles top-level error handling and logging

### 4. lib/immich_stacker/configuration.rb

**Class:** `ImmichStacker::Configuration`

**Responsibilities:**
- Load and validate environment variables:
  - `API_KEY` (required)
  - `API_ENDPOINT` (required)
  - `DRY_RUN` (optional, defaults to "false")
  - `CONFIG_PATH` (optional, defaults to "config.json")
- Parse JSON configuration file
- Expose configuration as methods/attributes

**Interface:**
```ruby
class Configuration
  attr_reader :api_key, :api_endpoint, :dry_run, :groupings

  def initialize
  def dry_run?
end
```

### 5. lib/immich_stacker/api_client.rb

**Class:** `ImmichStacker::ApiClient`

**Responsibilities:**
- Initialize Faraday connection with base URL and headers
- Implement `fetch_all_assets` - paginated fetching from `GET /search/assets`
- Implement `create_stack(primary_asset_id, asset_ids)` - `POST /stacks`
- Handle API errors gracefully

**Interface:**
```ruby
class ApiClient
  def initialize(api_endpoint:, api_key:)
  def fetch_all_assets  # Returns array of raw asset hashes
  def create_stack(primary_asset_id:, asset_ids:)  # Creates stack via API
end
```

**API Details:**
- `GET /search/assets` with pagination (`page`, `size` params)
- `POST /stacks` with body: `{ "assetIds": ["primary_id", "other_id", ...] }`
- Header: `x-api-key: <API_KEY>`

### 6. lib/immich_stacker/asset.rb

**Class:** `ImmichStacker::Asset`

**Responsibilities:**
- Wrap raw API response hash
- Parse and expose fields:
  - `id` - Asset UUID
  - `original_path` - Full path from API
  - `directory` - Extracted directory portion
  - `filename` - Extracted filename (without extension)
  - `extension` - Extracted file extension (without dot)
  - `exif_date` - DateTimeOriginal from `exifInfo`
  - `stack_id` - Current stack ID (nil if not stacked)
- Provide `stacked?` method

**Interface:**
```ruby
class Asset
  attr_reader :id, :original_path, :directory, :filename, :extension, :exif_date, :stack_id

  def initialize(api_response)
  def stacked?
  def field(name)  # Returns field value by name string
end
```

### 7. lib/immich_stacker/operation.rb

**Class:** `ImmichStacker::Operation`

**Responsibilities:**
- Parse operation hash from config (`field`, `pattern`, `index`)
- Evaluate operation against an Asset
- Return matched value or nil

**Interface:**
```ruby
class Operation
  def initialize(config_hash)
  def evaluate(asset)  # Returns matched value or nil
end
```

**Logic:**
```ruby
def evaluate(asset)
  value = asset.field(@field)
  return nil if value.nil?
  
  if @pattern
    match = value.match(@pattern)
    return nil unless match
    match[@index || 0]
  else
    value
  end
end
```

### 8. lib/immich_stacker/grouping.rb

**Class:** `ImmichStacker::Grouping`

**Responsibilities:**
- Parse grouping configuration hash
- Build Operation objects for inclusion, criteria, and parent operations
- Provide methods to:
  - Check if asset matches inclusion criteria
  - Generate grouping key for asset
  - Determine parent from group of assets

**Interface:**
```ruby
class Grouping
  def initialize(config_hash)
  def matches_inclusion?(asset)  # All inclusion operations must pass
  def grouping_key(asset)        # Concatenated criteria operation results
  def determine_parent(assets)   # First asset matching parent_operations, or last
end
```

### 9. lib/immich_stacker/stacker.rb

**Class:** `ImmichStacker::Stacker`

**Responsibilities:**
- Orchestrate the entire stacking process
- Fetch all assets via API client
- Convert to Asset objects
- Filter out already-stacked assets
- For each grouping configuration:
  1. Filter assets by inclusion operations
  2. Group assets by criteria operations (build grouping key)
  3. For each group with 2+ assets:
     - Determine parent using parent operations
     - Create stack via API (unless dry run)
- Log progress and results

**Interface:**
```ruby
class Stacker
  def initialize(configuration:, api_client:)
  def run
end
```

**Algorithm:**
```ruby
def run
  assets = fetch_and_parse_assets
  unstacked_assets = assets.reject(&:stacked?)
  
  config.groupings.each do |grouping|
    # Filter by inclusion
    candidates = unstacked_assets.select { |a| grouping.matches_inclusion?(a) }
    
    # Group by criteria
    groups = candidates.group_by { |a| grouping.grouping_key(a) }
    
    # Process each group
    groups.each do |key, group_assets|
      next if group_assets.size < 2
      
      parent = grouping.determine_parent(group_assets)
      children = group_assets - [parent]
      
      if dry_run?
        log_dry_run(parent, children)
      else
        api_client.create_stack(
          primary_asset_id: parent.id,
          asset_ids: [parent.id] + children.map(&:id)
        )
      end
    end
  end
end
```

### 10. config.json

**Structure:**
```json
{
  "groupings": [
    {
      "inclusion_operations": [
        { "field": "extension", "pattern": "^(jpe?g|cr2)$" }
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

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `API_KEY` | Yes | - | Immich API key for authentication |
| `API_ENDPOINT` | Yes | - | Immich API base URL (e.g., `https://immich.example.com/api`) |
| `DRY_RUN` | No | `false` | If `true`, log actions without creating stacks |
| `CONFIG_PATH` | No | `config.json` | Path to configuration file |

## Data Flow

```
1. Load Configuration
   ├── Read environment variables
   └── Parse config.json

2. Fetch Assets
   ├── Call GET /search/assets (paginated)
   └── Parse into Asset objects

3. Filter Stacked Assets
   └── Remove assets where stack_id is present

4. For Each Grouping:
   ├── 4a. Apply Inclusion Filters
   │       └── Keep only assets where ALL inclusion operations pass
   │
   ├── 4b. Build Grouping Keys
   │       └── Concatenate results of all criteria operations
   │
   ├── 4c. Group Assets by Key
   │       └── Hash: key => [assets]
   │
   └── 4d. Create Stacks
           ├── Skip groups with < 2 assets
           ├── Determine parent (first matching parent_operation, or last)
           └── POST /stacks with parent first in assetIds array

5. Report Results
   └── Log created stacks or dry-run summary
```

## Error Handling

- **Missing required env vars**: Exit with clear error message
- **Invalid config.json**: Exit with JSON parse error details
- **API errors**: Log error, continue processing other groups
- **No matches**: Log informational message, exit cleanly

## Testing Considerations

For future implementation:
- Unit tests for Operation evaluation
- Unit tests for Asset field parsing
- Integration tests for Grouping logic
- Mock API responses for Stacker tests

## Usage

```bash
# Set required environment variables
export API_KEY="your-api-key"
export API_ENDPOINT="https://immich.example.com/api"

# Optional: dry run mode
export DRY_RUN=true

# Run the stacker
./bin/stack
```
