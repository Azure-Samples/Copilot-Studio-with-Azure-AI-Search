# Heading Levels Incorrect in Table of Contents

##

/workspaces/Copilot-Studio-with-Azure-AI-Search/README.md

## Problem

In the Table of Contents section, heading levels for anchored links are not properly aligned with their corresponding section titles' actual levels in the markdown file. For example, entries like `- [3.1 Prerequisites](#prerequisites)` suggest it's a lower-level heading, while in the file it is represented as a "###" heading. This may lead to confusion for readers trying to navigate the document, as the structure does not visually differentiate between main sections and subsections.

## Impact

- Medium: This affects usability and navigation, especially for large documentation where properly indented and structured table of contents is essential for quickly finding sections.

## Location

Table of Contents section, at the start of the file.

## Code Issue

```
- [3.1 Prerequisites](#prerequisites)
  - [3.1.1 App Registration and Service Principal Setup](#app-registration-and-service-principal-setup)
  - [3.1.2 User Configuration](#user-configuration)
  - [3.1.3 Development Environment Setup](#development-environment-setup)
```

## Fix

Ensure the Table of Contents visually resembles the heading hierarchy, using indentation for subsections:

```
- [1. Features](#features)
- [2. Architecture](#architecture)
- [3. Getting Started](#getting-started)
  - [3.1 Prerequisites](#prerequisites)
    - [3.1.1 App Registration and Service Principal Setup](#app-registration-and-service-principal-setup)
    - [3.1.2 User Configuration](#user-configuration)
    - [3.1.3 Development Environment Setup](#development-environment-setup)
  - [3.2 Quickstart](#quickstart)
    - [3.2.1 Deployment Instructions](#deployment-instructions)
```
