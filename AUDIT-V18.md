# V18 scope and verification boundary

## Scope
V18 is the simplified core interaction foundation: composer-first Home; For You / Following / Latest; Discover; Circles; Messages; Me; Whisper actions; Memory; and separate person-follow versus discussion-subscription behavior.

## Uniqueness goal
The interface should support a thought's journey rather than add generic social-media clutter: publish a Whisper, encounter relevant perspectives, develop dialogue, preserve meaningful contributions, and return to them. The product vocabulary is kept consistent and action labels are not duplicated across competing destinations.

## Explicitly out of V18
New AI-generated interpretation, translation/summarization, Whisper Journey lineage, governed no-code Studio/App Lab, and broad privacy/consent redesign belong to later phases unless needed to fix a blocking core defect. See `ROADMAP-V18-TO-V21.md`.

## Known verification boundary
Build checks can verify JavaScript syntax, static regression assertions, expected files, and ZIP integrity. They cannot prove live Supabase schema compatibility, RLS policies, notifications, or actual mobile browser layout. These remain staging gates.
