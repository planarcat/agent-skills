---
name: agentic-ui-walkthrough
description: Structured UI review sessions combining bug hunting, UX assessment, and visual verification. Use when reviewing implemented UIs for quality, usability, and correctness.
---

# Agentic UI Walkthrough Skill

Systematic approach to reviewing user interfaces — finding bugs, assessing UX quality, and verifying visual correctness through screenshot-driven analysis.

## When to Use

- After implementing UI changes (web, Electron, SwiftUI, native)
- Before presenting work to the user for review
- When the user reports visual issues or "something feels off"
- During UI polish or UX improvement sprints
- As part of the audit/harden cycle in Codex collaboration

## Screenshot-Driven Review Flow

### Step 1: Capture Baseline

Capture screenshots of every distinct UI state.

> [!IMPORTANT]
> **For Command Center (Electron/Web):** CC agents call the MCP API for visual testing using the `visual-review` skill (`.agent/skills/visual-review/SKILL.md`). CC agents must NOT run Playwright or capture screenshots directly. The commands below apply only to UX Visual Reviewer-resident agents or platform-specific contexts (iOS/watchOS).

```bash
# iOS/iPad simulator
xcrun simctl io DEVICE_UUID screenshot /tmp/ui-baseline.png

# watchOS simulator
xcrun simctl io DEVICE_UUID screenshot /tmp/watch-baseline.png
```

### Step 2: Walk Through Every State

Document each state you can reach:
- Default/empty state
- Loading state
- Populated/data state
- Error state
- Edge cases (no data, very long text, single item, 100+ items)

### Step 3: Analyze Against Heuristics

Use the UX Heuristic Checklist (below) to systematically evaluate each screen.

### Step 4: Document Findings

Create a prioritized report with embedded screenshots showing issues.

### Step 5: Fix ALL Findings

> [!CAUTION]
> **Every P-level finding must be fixed** — not deferred, dismissed, or rationalized. Agents must NEVER classify findings as "acceptable," "cosmetic-only," or "not the major issue." UX Visual Reviewer checks are explicitly refined by the project owner and are intentional. If the NRQA or visual review flags it, fix it. The only exception is a single finding estimated at >2 hours of work — document it as a follow-up issue with user confirmation.

- **P0-P1:** Fix immediately — blocks ship
- **P2:** Fix in the same session — do NOT defer
- **P3:** Fix in the same session — do NOT log for "future iteration"

## UX Heuristic Checklist

Rate each item ✅ (good), ⚠️ (needs work), or ❌ (broken):

### Visual Design
- [ ] **Visual hierarchy** — most important information is prominent
- [ ] **Consistent spacing** — margins and padding follow a system (4/8/12/16/24px)
- [ ] **Typography** — readable font sizes, clear hierarchy (h1 > h2 > body > caption)
- [ ] **Color contrast** — text is readable against background (WCAG AA minimum)
- [ ] **Alignment** — elements are properly aligned (no off-by-1 pixel issues)
- [ ] **Empty states** — empty views have helpful messaging, not blank screens
- [ ] **Loading states** — spinners/skeletons show when data is loading
- [ ] **Error states** — errors are clearly communicated with actionable recovery

### Interaction Design
- [ ] **Responsive** — layout works at all supported sizes
- [ ] **Touch targets** — buttons/links are at least 44×44pt (mobile) or clearly clickable (web)
- [ ] **Feedback** — user actions have visible responses (hover, press, loading)
- [ ] **Navigation** — user always knows where they are and how to go back
- [ ] **Affordance** — interactive elements look interactive
- [ ] **Consistency** — similar actions behave the same way everywhere

### Content & Data
- [ ] **Data freshness** — displayed data reflects current state
- [ ] **Overflow handling** — long text truncates gracefully (ellipsis, not clipping)
- [ ] **Number formatting** — numbers, dates, times are formatted for readability
- [ ] **Localization-ready** — no hardcoded strings that would break in translation

### Performance & Polish
- [ ] **Smooth transitions** — animations are fluid, no jank
- [ ] **No layout shifts** — content doesn't jump around during load
- [ ] **Image quality** — images are sharp on retina displays
- [ ] **Scroll performance** — long lists scroll smoothly

## Bug Classification Matrix

| Category | Examples | Priority |
|----------|----------|----------|
| **Crash** | App crashes on action, unhandled exception | P0 |
| **Data Loss** | User input lost, unsaved changes discarded | P0 |
| **Functional** | Button does nothing, wrong data displayed | P1 |
| **Visual** | Layout broken, overlapping elements, wrong colors | P1 |
| **UX** | Confusing flow, missing feedback, poor affordance | P2 |
| **Performance** | Slow load, janky scroll, delayed response | P2 |
| **Polish** | Minor spacing, subtle animation issues | P3 |
| **Accessibility** | Missing labels, low contrast, no keyboard nav | P2 |

## Review Report Format

```markdown
# UI Review: [Feature/Screen Name]

**Date:** YYYY-MM-DD
**Platform:** [Web/iOS/iPadOS/watchOS/Electron]
**Reviewer:** [Agent name]

## Summary
[1-2 sentence overall assessment]

## Screenshots
![state-name](path/to/screenshot.png)

## Findings

### P1 — Must Fix
1. **[Title]** — [Description]
   - Screenshot: [reference]
   - Location: [file:line]
   - Suggested fix: [approach]

### P2 — Should Fix
...

### P3 — Nice to Have
...

## UX Scorecard
| Category | Score |
|----------|-------|
| Visual Design | ✅ / ⚠️ / ❌ |
| Interaction | ✅ / ⚠️ / ❌ |
| Content & Data | ✅ / ⚠️ / ❌ |
| Performance | ✅ / ⚠️ / ❌ |
```

## Platform-Specific Patterns

### Electron/Web
- **The running Electron app is the source of truth**, not `file://index.html` in a browser
- The app must be launched (`npm start` or `npx electron electron/main.js`) and fully initialized before testing
- Test at multiple viewport sizes (resize browser tool)
- Check dark mode vs light mode
- Verify all interactive elements have unique IDs for testing
- Test keyboard navigation (Tab, Enter, Escape)
- **Exercise EVERY sidebar/navigation view** — if the app has 3+ nav rail buttons, click each one and verify:
  - The correct panel appears
  - The previous panel is hidden (not overlapping)
  - Switching back restores the original view
- **Verify IPC-dependent features load real data:**
  - Workspace cards should populate from detected VS Code windows
  - Machine list should populate from network config
  - Plan Router should show pending plans (if any exist)
  - If data doesn't load, investigate and document why
- **Test collapsible/expandable UI:** menus, dropdowns, panels, modals, settings
- **Check styled components:** form inputs, buttons, and selects should match the app's theme — raw unstyled HTML inputs indicate missing CSS

### SwiftUI (iOS/iPad/Watch)
- Test both light and dark appearance
- Test Dynamic Type (accessibility font sizes)
- Check Safe Area handling (notch, home indicator)
- Verify NavigationStack push/pop animations
- Test rotating orientation (iPad)

### watchOS-Specific
- Verify Digital Crown scrolling
- Check text fits on small screens (40mm vs 49mm)
- Test complications if applicable
- Verify data loads before app is suspended

## Anti-Patterns to Catch

1. **"It works on my screen"** — always test multiple sizes/states
2. **Invisible errors** — errors that log but don't inform the user
3. **Phantom loading** — loading indicator that never resolves
4. **Dead-end states** — no way to recover or navigate away
5. **Data staleness** — showing cached data without indicating age
6. **Truncation without affordance** — text cut off with no way to see full content
7. **Inconsistent spacing** — mixing 10px, 12px, 15px instead of a spacing scale
8. **Missing empty states** — blank screen when there's no data

