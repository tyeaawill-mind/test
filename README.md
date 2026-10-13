# mindRID V19.0 Inventory Package

This is a source-only inventory based on the supplied V18.5 ZIP. It is not a production security certification.

- `V19.0-SOURCE-AND-SECURITY-INVENTORY.md`: findings and staged plan.
- `static_inventory.py`: reproducible static checks; run with Python and the extracted source directory as its argument.

No application code or database migrations are modified by this package. Before applying changes, compare the report with a redacted live Supabase schema/policy/function/grant export and migration history. Never share secret/service-role keys.
