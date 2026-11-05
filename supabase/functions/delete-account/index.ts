import { createClient } from "npm:@supabase/supabase-js@2";
import { createDeleteAccountHandler } from "./core.mjs";

const handler = createDeleteAccountHandler({
  env: (name: string) => Deno.env.get(name),
  createClient,
  log: console,
});

Deno.serve(handler);
