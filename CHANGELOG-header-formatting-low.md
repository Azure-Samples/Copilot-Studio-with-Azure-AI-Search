# Title

Header Formatting Issues in CHANGELOG.md

##

/workspaces/Copilot-Studio-with-Azure-AI-Search/CHANGELOG.md

## Problem

The file contains headings that are not followed by a blank line, which is against markdown best practices. For example, after the `## [project-title] Changelog` and `# x.y.z (yyyy-mm-dd)` headers, there is no blank line. This can cause rendering issues in some markdown viewers and reduces readability.

## Impact

Low. This does not impact the codebase directly but may cause readability and formatting problems in markdown renderers, which can be problematic for users reading the changelog.

## Location

Lines 1 and 4

## Code Issue

```
## [project-title] Changelog
<a name="x.y.z"></a>
# x.y.z (yyyy-mm-dd)
*Features*
* ...
```

## Fix

Add blank lines after headers to ensure correct markdown rendering.

```
## [project-title] Changelog

<a name="x.y.z"></a>

# x.y.z (yyyy-mm-dd)

*Features*
* ...
```
