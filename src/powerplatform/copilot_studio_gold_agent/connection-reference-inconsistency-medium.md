# Title

ConnectionReference Customizability Inconsistency

##

/src/powerplatform/copilot_studio_gold_agent/Assets/botcomponent_connectionreferenceset.xml
/src/powerplatform/copilot_studio_gold_agent/Other/Customizations.xml

## Problem

The `iscustomizable` value for the same connection reference appears inconsistent between two configuration files:

- In `botcomponent_connectionreferenceset.xml`: `<iscustomizable>1</iscustomizable>`
- In `Customizations.xml`: `<iscustomizable>0</iscustomizable>`

for the connection logical name `crf6d_aiSearchConnectionExample.cr.ERQq7Off`.

This inconsistency can create deployment and application lifecycle management issues, as customization permissions defined in solution files may conflict or confuse downstream migration/import tools or administrators as to whether this connection reference can be customized by users.

## Impact

Medium. This can lead to confusion for developers or administrators, may cause unexpected import behavior in Power Platform, and could impact application lifecycle management and support.

## Location

```
/workspaces/Copilot-Studio-with-Azure-AI-Search/src/powerplatform/copilot_studio_gold_agent/Assets/botcomponent_connectionreferenceset.xml
/workspaces/Copilot-Studio-with-Azure-AI-Search/src/powerplatform/copilot_studio_gold_agent/Other/Customizations.xml
```

## Code Issue

```xml
<!-- In botcomponent_connectionreferenceset.xml -->
<iscustomizable>1</iscustomizable>

<!-- In Customizations.xml -->
<iscustomizable>0</iscustomizable>
```

## Fix

Ensure that the customizability flag for this connection reference is consistent across both files. Decide if you want the connection reference to be customizable, and update both files so that the `<iscustomizable>` value matches (`0` for not customizable, `1` for customizable):

```xml
<iscustomizable>0</iscustomizable>
```

or

```xml
<iscustomizable>1</iscustomizable>
```

Update whichever file is incorrect to achieve the intended permissions consistency throughout the solution.
