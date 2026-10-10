# mindRID V18.4 — Home & Follow Controls

## Changes
- Restored the signed-in Home heading to **Home**.
- Removed the “Whispering” heading and the subtitle “Put down a Whisper, then encounter reflections worth returning to.”
- Kept the V17-style Home structure: composer followed by the Home feed and feed-mode selector.
- Restored a reliable mobile Home action: it returns to Home from other tabs; if already on Home, it scrolls to the top and focuses the composer.
- Added **Follow post / Following post** toggle to feed cards and the Whisper detail view. It subscribes to the existing post-discussion notification system; users can unfollow with the same control.
- Updated subscription state across every visible copy of the same post-follow button.
- Preserved the separate person **Follow / Following / Unfollow** controls and the existing `follows` relationship model.
- Updated the script cache-busting query so browsers request the revised JavaScript.

## Verification boundary
JavaScript syntax and static regression checks should be run before deployment. This package is not a substitute for live browser testing and Supabase/RLS verification with two accounts. Post follow subscribes to reply notifications; it does not follow the author. Following a person affects the Following feed.
