# UI Design System & Figma Translation Workflow

You have access to the Figma MCP server via `get_design_context`. When given a Figma URL, follow these strict execution guardrails:

## 1. Extraction Phase
- Extract global tokens (Colors, Typography) using `get_variable_defs`.
- Map them to `DesignSystem.swift` instead of hardcoding values.
- For watchOS layouts, convert fixed Figma frame widths into relative sizing, flexible paddings, or standard Spacers.

## 2. Safety & Logic Preservation Rules
- NEVER modify or delete existing application state logic (`@State`, `@StateObject`, `@EnvironmentObject`), timers, closures, or model bindings.
- If a view contains `AnimatedFigureView()`, preserve its hierarchy and bindings exactly as they are. Only modify the surrounding structural layout wrappers (`VStack`, `HStack`, `.padding`).

## 3. Layout Translation Rules
- Treat Figma Auto Layout parent frame "item-spacing" properties as the native `spacing:` parameter inside a SwiftUI `VStack` or `HStack`.
- NEVER generate dummy `Spacer().frame(height: X)` blocks to represent missing geometric shapes unless explicitly forced by a `Spacer()` wrapper layer.
- Map native Figma Auto Layout padding values strictly to the `.padding()` modifier or explicit layout bounds.

## 4. Human-in-the-Loop Approval Protocol
- Before modifying any file, present a Markdown table mapping out the proposed changes:
  | Figma Layer / Component | Targeted SwiftUI File | Action (New / Modify / Swap) |
- Halt execution and explicitly ask the user for confirmation before writing code.
