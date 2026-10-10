# V18.5 — Mobile Home Frame Restoration

## Target
Restore the signed-in smartphone Home composition to match the supplied reference: distinct Home heading; full-width For You / Following / Latest tabs; compact one-line composer prompt with a Whisper action; feed begins below the composer. Preserve the rest of V18 behavior and the guest landing page.

## Changes
- Added a dedicated mobile composer trigger to signed-in Home, wired to the existing `data-action="compose"` action.
- Mobile feed tabs now occupy the full width in three equal columns, with a clear active underline.
- Kept desktop composer and desktop feed layout unchanged; the full composer remains available through the existing compose modal on mobile.
- Prevented the floating compose button from duplicating the visible Whisper action on mobile Home.
- Kept the mobile prompt on one line with ellipsis on narrow screens and bounded avatar/action widths.
- Updated CSS/JS cache-busting query strings.

## Frame-by-frame audit
1. **Top brand/account frame:** no markup or style changes to the top bar.
2. **Home title frame:** mobile title is a standalone full-width row with its own divider.
3. **Feed-mode frame:** three equal-width tabs, no pill chips, active tab underline.
4. **Composer frame:** avatar, one-line prompt, and Whisper action on a single row; no oversized expanding avatar/shape.
5. **Feed frame:** feed cards begin after the composer row and retain normal scrolling.
6. **Navigation frame:** existing bottom navigation remains; redundant floating plus is hidden on mobile Home only.
7. **Other routes and guest landing:** no intended changes.

## Checks
- `node --check app.js`: passed.
- ZIP integrity: checked after packaging.
- Static source assertions: passed for the mobile trigger, three-column tab frame, one-line prompt, and mobile Home floating-button suppression.
- Not performed: real iPhone/Safari visual test, authenticated Supabase browser test, or production deployment. Validate at 320, 375/390, and 430 CSS-pixel widths in staging.
