const ALLOWED_ORIGINS = new Set([
  "https://mindrid.com",
  "https://www.mindrid.com",
  "http://localhost:4173",
  "http://127.0.0.1:4173",
]);
const CORS_HEADERS = {
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
  "Vary": "Origin",
};

const BUCKET = "mindrid-media";
const PAGE_SIZE = 100;
const REMOVE_BATCH_SIZE = 100;
const MAX_OBJECTS_PER_REQUEST = 100_000;
const MAX_FOLDER_DEPTH = 32;

function corsHeadersFor(req) {
  const headers = { ...CORS_HEADERS };
  const origin = req.headers.get("Origin");
  if (origin && ALLOWED_ORIGINS.has(origin)) headers["Access-Control-Allow-Origin"] = origin;
  return headers;
}

function json(status, body, req) {
  return new Response(JSON.stringify(body), { status, headers: corsHeadersFor(req) });
}

function safeEntryName(name) {
  return typeof name === "string" && name.length > 0 && name !== "." && name !== ".." && !name.includes("/") && !name.includes("\\");
}

/**
 * Dependency-injected handler so account-deletion control flow can be simulated
 * in Node without production credentials or a live Supabase project.
 */
export function createDeleteAccountHandler({ env, createClient, log = console }) {
  return async function handleDeleteAccount(req) {
    if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeadersFor(req) });
    if (req.method !== "POST") return json(405, { error: "Method not allowed." }, req);

    const authorization = req.headers.get("Authorization");
    if (!authorization || !/^Bearer\s+\S+/i.test(authorization)) {
      return json(401, { error: "Please sign in again before deleting your account." }, req);
    }
    const token = authorization.replace(/^Bearer\s+/i, "").trim();

    let body;
    try {
      body = await req.json();
    } catch {
      return json(400, { error: "A deletion confirmation is required." }, req);
    }
    if (!body || body.confirm !== "DELETE") {
      return json(400, { error: "Confirm permanent deletion before continuing." }, req);
    }

    const supabaseUrl = env("SUPABASE_URL");
    const anonKey = env("SUPABASE_ANON_KEY");
    const serviceRoleKey = env("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !anonKey || !serviceRoleKey) {
      log.error?.("Required Supabase environment variables are missing.");
      return json(500, { error: "Account deletion is not configured. Please contact support." }, req);
    }

    const userClient = createClient(supabaseUrl, anonKey, {
      auth: { persistSession: false, autoRefreshToken: false },
      global: { headers: { Authorization: `Bearer ${token}` } },
    });
    const { data: authData, error: authError } = await userClient.auth.getUser(token);
    if (authError || !authData?.user?.id) {
      return json(401, { error: "Your session is invalid or expired. Sign in again." }, req);
    }
    const userId = authData.user.id;

    // Enforce the MFA gate on the server. A frontend-only check can be bypassed
    // by calling the Edge Function directly with a valid bearer token.
    const { data: factorData, error: factorError } = await userClient.auth.mfa.listFactors();
    if (factorError) {
      log.error?.("Could not verify account MFA state", { userId, error: factorError.message });
      return json(503, { error: "We could not verify your security settings. Please retry." }, req);
    }
    const hasVerifiedTotp = (factorData?.totp ?? []).some((factor) => factor?.status === "verified");
    if (hasVerifiedTotp) {
      const { data: aalData, error: aalError } = await userClient.auth.mfa.getAuthenticatorAssuranceLevel();
      if (aalError) {
        log.error?.("Could not verify account assurance level", { userId, error: aalError.message });
        return json(503, { error: "We could not verify two-factor authentication. Please retry." }, req);
      }
      if (aalData?.currentLevel !== "aal2") {
        return json(403, { error: "Complete two-factor authentication before deleting your account." }, req);
      }
    }

    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    // Temporarily hide the profile before enumerating media. The matching
    // storage-policy migration blocks new uploads/updates for deactivated users,
    // closing the upload-vs-delete race. Restore the previous state on failure.
    let profileRead;
    try {
      profileRead = await admin.from("profiles").select("is_deactivated").eq("id", userId).maybeSingle();
    } catch (error) {
      log.error?.("Could not read profile state before account deletion", { userId, error: String(error) });
      return json(503, { error: "We could not safely prepare your account for deletion. Please retry later." }, req);
    }
    const { data: profileState, error: profileReadError } = profileRead;
    if (profileReadError) {
      log.error?.("Could not read profile state before account deletion", { userId, error: profileReadError.message });
      return json(503, { error: "We could not safely prepare your account for deletion. Please retry later." }, req);
    }
    const originalDeactivated = profileState ? Boolean(profileState.is_deactivated) : null;
    let profileLockApplied = false;
    async function restoreProfileState() {
      if (!profileLockApplied) return true;
      try {
        const { error } = await admin.from("profiles").update({ is_deactivated: originalDeactivated }).eq("id", userId);
        if (error) {
          log.error?.("Could not restore profile state after failed account deletion", { userId, error: error.message });
          return false;
        }
        profileLockApplied = false;
        return true;
      } catch (error) {
        log.error?.("Could not restore profile state after failed account deletion", { userId, error: String(error) });
        return false;
      }
    }
    if (profileState && !originalDeactivated) {
      // Mark the lock as pending before awaiting the write so even a network
      // exception after a committed update triggers a best-effort restoration.
      profileLockApplied = true;
      let lockError = null;
      try {
        const result = await admin.from("profiles").update({ is_deactivated: true }).eq("id", userId);
        lockError = result.error;
      } catch (error) {
        lockError = error;
      }
      if (lockError) {
        log.error?.("Could not lock profile during account deletion", { userId, error: String(lockError.message ?? lockError) });
        const restored = await restoreProfileState();
        return json(503, { error: restored
          ? "We could not safely prepare your account for deletion. Please retry later."
          : "Your profile may have been hidden while preparing deletion. Please contact support before reactivating your account." }, req);
      }
    }

    const paths = [];
    let visitedObjects = 0;

    async function collectFolder(folder, depth = 0) {
      if (depth > MAX_FOLDER_DEPTH) throw new Error("Storage folder nesting exceeds the safety limit.");
      let offset = 0;
      while (true) {
        const { data, error } = await admin.storage.from(BUCKET).list(folder, {
          limit: PAGE_SIZE,
          offset,
          sortBy: { column: "name", order: "asc" },
        });
        if (error) throw new Error(`Could not enumerate account media: ${error.message}`);
        const entries = data ?? [];
        for (const entry of entries) {
          if (!safeEntryName(entry?.name)) throw new Error("Storage returned an unsafe entry name.");
          visitedObjects += 1;
          if (visitedObjects > MAX_OBJECTS_PER_REQUEST) {
            throw new Error("Account media exceeds the safe per-request enumeration limit.");
          }
          const path = `${folder}/${entry.name}`;
          if (entry.id == null) {
            await collectFolder(path, depth + 1);
          } else {
            paths.push(path);
          }
        }
        if (entries.length < PAGE_SIZE) break;
        offset += entries.length;
      }
    }

    try {
      await collectFolder(userId);
    } catch (error) {
      log.error?.("Account media enumeration failed", { userId, error: String(error) });
      const restored = await restoreProfileState();
      return json(503, { error: restored
        ? "We could not safely prepare your media for deletion. No account deletion was attempted; please retry later or contact support."
        : "Deletion could not proceed and your profile may remain hidden. Please contact support before reactivating your account." }, req);
    }

    // Never delete auth.users unless every requested Storage API batch succeeds.
    async function removeBatches(batchPaths, offsetLabel = 0) {
      for (let i = 0; i < batchPaths.length; i += REMOVE_BATCH_SIZE) {
        const batch = batchPaths.slice(i, i + REMOVE_BATCH_SIZE);
        try {
          const { error } = await admin.storage.from(BUCKET).remove(batch);
          if (error) {
            log.error?.("Account media removal failed", { userId, removedBatchStart: offsetLabel + i, error: error.message });
            return false;
          }
        } catch (error) {
          log.error?.("Account media removal threw an exception", { userId, removedBatchStart: offsetLabel + i, error: String(error) });
          return false;
        }
      }
      return true;
    }
    const firstPass = await removeBatches(paths);
    if (!firstPass) {
      const restored = await restoreProfileState();
      return json(503, { error: restored
        ? "Some account media could not be deleted. Your account was not deleted; please retry to finish safely."
        : "Some media could not be deleted and your profile may remain hidden. Please contact support before reactivating your account." }, req);
    }

    // Sweep once more after the upload lock to catch an upload that was already
    // in flight when the profile was deactivated. Successful removals from pass
    // one should no longer be listed, so this collects only late-arriving paths.
    const previousPathCount = paths.length;
    try {
      await collectFolder(userId);
    } catch (error) {
      log.error?.("Final account media sweep failed", { userId, error: String(error) });
      const restored = await restoreProfileState();
      return json(503, { error: restored
        ? "A final media check failed. Your account was not deleted; please retry."
        : "A final media check failed and your profile may remain hidden. Please contact support." }, req);
    }
    const latePaths = paths.slice(previousPathCount);
    if (latePaths.length && !(await removeBatches(latePaths, previousPathCount))) {
      const restored = await restoreProfileState();
      return json(503, { error: restored
        ? "Some newly arriving media could not be deleted. Your account was not deleted; please retry."
        : "Some newly arriving media could not be deleted and your profile may remain hidden. Please contact support." }, req);
    }

    let deleteError = null;
    try {
      const result = await admin.auth.admin.deleteUser(userId);
      deleteError = result.error;
    } catch (error) {
      deleteError = error;
    }
    if (deleteError) {
      log.error?.("Auth account deletion failed after media cleanup", { userId, error: String(deleteError.message ?? deleteError) });
      const restored = await restoreProfileState();
      return json(503, { error: restored
        ? "Your media cleanup completed, but account deletion did not finish. Please retry; the operation is designed to be safe to retry."
        : "Your media cleanup completed, but account deletion did not finish and your profile may remain hidden. Please contact support." }, req);
    }

    return json(200, { success: true, deletedMediaCount: paths.length }, req);
  };
}
