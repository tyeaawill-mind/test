import assert from 'node:assert/strict';
import { createDeleteAccountHandler } from '../supabase/functions/delete-account/core.mjs';

const USER_ID = '11111111-2222-4333-8444-555555555555';
const TOKEN = 'valid-test-token';
const ENV = {
  SUPABASE_URL: 'https://simulation.invalid',
  SUPABASE_ANON_KEY: 'test-anon',
  SUPABASE_SERVICE_ROLE_KEY: 'test-service-role',
};

function fixture(options = {}) {
  const state = {
    deletedUsers: [], removed: [], listCalls: [],
    adminClientCreated: false,
    profileState: options.profileState === undefined ? false : options.profileState,
    profileReadError: options.profileReadError ?? null,
    profileUpdateError: options.profileUpdateError ?? null,
    lateUpload: options.lateUpload ?? false,
    lateUploadAdded: false,
    userFactors: options.factors ?? { totp: [] },
    aal: options.aal ?? { currentLevel: 'aal1', nextLevel: 'aal1' },
    listError: options.listError ?? null,
    removeError: options.removeError ?? null,
    deleteError: options.deleteError ?? null,
    entries: options.entries ?? { [USER_ID]: [] },
  };
  const userClient = {
    auth: {
      getUser: async (token) => token === TOKEN
        ? { data: { user: { id: USER_ID } }, error: null }
        : { data: { user: null }, error: { message: 'bad token' } },
      mfa: {
        listFactors: async () => ({ data: state.userFactors, error: options.factorError ?? null }),
        getAuthenticatorAssuranceLevel: async () => ({ data: state.aal, error: options.aalError ?? null }),
      },
    },
  };
  const adminClient = {
    from: (table) => {
      let mode = 'select'; let patch = null; let selectedId = null;
      const chain = {
        select() { mode = 'select'; return this; },
        update(value) { mode = 'update'; patch = value; return this; },
        eq(_column, value) { selectedId = value; return this; },
        async maybeSingle() {
          if (table !== 'profiles' || selectedId !== USER_ID) return { data: null, error: null };
          if (state.profileReadError) return { data: null, error: state.profileReadError };
          return { data: state.profileState === null ? null : { is_deactivated: state.profileState }, error: null };
        },
        then(resolve, reject) {
          if (mode === 'update' && table === 'profiles' && selectedId === USER_ID) {
            if (!state.profileUpdateError && state.profileState !== null) state.profileState = patch.is_deactivated;
            return Promise.resolve({ data: null, error: state.profileUpdateError }).then(resolve, reject);
          }
          return Promise.resolve({ data: null, error: null }).then(resolve, reject);
        },
      };
      return chain;
    },
    storage: { from: (bucket) => ({
      list: async (folder, page) => {
        state.listCalls.push({ bucket, folder, ...page });
        if (state.listError) return { data: null, error: state.listError };
        const entries = [...(state.entries[folder] ?? [])].sort((a,b) => a.name.localeCompare(b.name));
        return { data: entries.slice(page.offset, page.offset + page.limit), error: null };
      },
      remove: async (paths) => {
        state.removed.push([...paths]);
        if (state.removeError) return { data: null, error: state.removeError };
        for (const path of paths) {
          const slash = path.lastIndexOf('/');
          const folder = path.slice(0, slash); const name = path.slice(slash + 1);
          if (state.entries[folder]) state.entries[folder] = state.entries[folder].filter((entry) => entry.name !== name);
        }
        if (state.lateUpload && !state.lateUploadAdded) {
          state.lateUploadAdded = true;
          state.entries[USER_ID] = [...(state.entries[USER_ID] ?? []), { id: 'late-id', name: 'late-upload.png' }];
        }
        return { data: null, error: null };
      },
    }) },
    auth: { admin: { deleteUser: async (id) => {
      state.deletedUsers.push(id);
      return { error: state.deleteError };
    } } },
  };
  const handler = createDeleteAccountHandler({
    env: (key) => ENV[key],
    createClient: (_url, key) => {
      if (key === ENV.SUPABASE_ANON_KEY) return userClient;
      state.adminClientCreated = true;
      return adminClient;
    },
    log: { error() {} },
  });
  const request = ({ method = 'POST', authorization = `Bearer ${TOKEN}`, body = { confirm: 'DELETE' }, origin = null } = {}) => new Request('https://simulation.invalid/functions/v1/delete-account', {
    method,
    headers: { ...(authorization ? { Authorization: authorization } : {}), ...(origin ? { Origin: origin } : {}), 'Content-Type': 'application/json' },
    body: method === 'POST' ? JSON.stringify(body) : undefined,
  });
  return { state, handler, request };
}

async function run() {
  {
    const f = fixture();
    const r = await f.handler(f.request({ authorization: null }));
    assert.equal(r.status, 401); assert.equal(f.state.adminClientCreated, false);
  }
  {
    const f = fixture();
    const r = await f.handler(f.request({ body: { confirm: true } }));
    assert.equal(r.status, 400); assert.equal(f.state.adminClientCreated, false);
  }
  {
    const f = fixture({ factors: { totp: [{ status: 'verified', id: 'factor-1' }] }, aal: { currentLevel: 'aal1' } });
    const r = await f.handler(f.request());
    assert.equal(r.status, 403); assert.equal(f.state.listCalls.length, 0); assert.equal(f.state.deletedUsers.length, 0);
  }
  {
    const f = fixture({ factorError: { message: 'simulated factor lookup failure' } });
    const r = await f.handler(f.request());
    assert.equal(r.status, 503); assert.equal(f.state.adminClientCreated, false); assert.equal(f.state.deletedUsers.length, 0);
  }
  {
    const f = fixture({ factors: { totp: [{ status: 'verified', id: 'factor-1' }] }, aalError: { message: 'simulated AAL lookup failure' } });
    const r = await f.handler(f.request());
    assert.equal(r.status, 503); assert.equal(f.state.deletedUsers.length, 0);
  }
  {
    const f = fixture({ profileReadError: { message: 'simulated profile read failure' } });
    const r = await f.handler(f.request());
    assert.equal(r.status, 503); assert.equal(f.state.listCalls.length, 0); assert.equal(f.state.deletedUsers.length, 0);
  }
  {
    const f = fixture({ profileUpdateError: { message: 'simulated profile lock failure' } });
    const r = await f.handler(f.request());
    assert.equal(r.status, 503); assert.equal(f.state.listCalls.length, 0); assert.equal(f.state.deletedUsers.length, 0);
  }
  {
    const f = fixture({ factors: { totp: [{ status: 'verified', id: 'factor-1' }] }, aal: { currentLevel: 'aal2' }, listError: { message: 'simulated listing failure' } });
    const r = await f.handler(f.request());
    assert.equal(r.status, 503); assert.equal(f.state.deletedUsers.length, 0); assert.equal(f.state.profileState, false);
  }
  {
    const f = fixture({ removeError: { message: 'simulated removal failure' }, entries: { [USER_ID]: [{ id: 'object-id', name: 'file.png' }] } });
    const r = await f.handler(f.request());
    assert.equal(r.status, 503); assert.equal(f.state.deletedUsers.length, 0); assert.equal(f.state.profileState, false);
  }
  {
    const f = fixture({ deleteError: { message: 'simulated auth deletion failure' }, entries: { [USER_ID]: [{ id: 'object-id', name: 'file.png' }] } });
    const r = await f.handler(f.request());
    assert.equal(r.status, 503); assert.deepEqual(f.state.deletedUsers, [USER_ID]);
    assert.equal(f.state.removed.flat().length, 1); assert.equal(f.state.profileState, false);
  }
  {
    const root = Array.from({ length: 101 }, (_, i) => ({ id: `id-${i}`, name: `file-${String(i).padStart(3, '0')}.png` }));
    root.push({ id: null, name: 'nested' });
    const f = fixture({
      factors: { totp: [{ status: 'verified', id: 'factor-1' }] },
      aal: { currentLevel: 'aal2' },
      entries: { [USER_ID]: root, [`${USER_ID}/nested`]: [{ id: 'nested-1', name: 'inside.pdf' }, { id: 'nested-2', name: 'inside.mp4' }] },
    });
    const r = await f.handler(f.request());
    const body = await r.json();
    assert.equal(r.status, 200); assert.equal(body.success, true); assert.equal(body.deletedMediaCount, 103);
    assert.deepEqual(f.state.deletedUsers, [USER_ID]);
    assert.equal(f.state.profileState, true, 'profile is locked before cleanup and remains deactivated after account deletion');
    assert.equal(f.state.removed.flat().length, 103);
    assert.ok(f.state.listCalls.some((x) => x.folder === USER_ID && x.offset === 100), 'root pagination is exercised');
    assert.ok(f.state.listCalls.some((x) => x.folder === `${USER_ID}/nested`), 'nested folder traversal is exercised');
    assert.ok(f.state.removed.every((batch) => batch.length <= 100), 'removals are batched');
  }
  {
    const f = fixture({ lateUpload: true, entries: { [USER_ID]: [{ id: 'initial-id', name: 'initial.png' }] } });
    const r = await f.handler(f.request());
    const body = await r.json();
    assert.equal(r.status, 200); assert.equal(body.deletedMediaCount, 2);
    assert.ok(f.state.removed.flat().includes(`${USER_ID}/late-upload.png`), 'second sweep removes a late-arriving upload');
    assert.deepEqual(f.state.deletedUsers, [USER_ID]);
  }
  {
    const f = fixture({ entries: { [USER_ID]: [{ id: null, name: '../escape' }] } });
    const r = await f.handler(f.request());
    assert.equal(r.status, 503); assert.equal(f.state.deletedUsers.length, 0);
  }
  {
    const f = fixture();
    const r = await f.handler(f.request({ method: 'GET' }));
    assert.equal(r.status, 405);
  }
  {
    const f = fixture();
    const allowed = await f.handler(f.request({ method: 'OPTIONS', origin: 'https://mindrid.com' }));
    assert.equal(allowed.headers.get('Access-Control-Allow-Origin'), 'https://mindrid.com');
    const rejected = await f.handler(f.request({ method: 'OPTIONS', origin: 'https://attacker.example' }));
    assert.equal(rejected.headers.get('Access-Control-Allow-Origin'), null);
  }
  console.log('PASS: rejects unauthenticated requests');
  console.log('PASS: requires explicit deletion confirmation');
  console.log('PASS: server enforces verified-TOTP AAL2 and fails closed on MFA lookup errors');
  console.log('PASS: profile-state read/lock failures stop before media cleanup');
  console.log('PASS: listing failure never deletes auth account and restores profile state');
  console.log('PASS: storage removal failure never deletes auth account and restores profile state');
  console.log('PASS: auth deletion failure is surfaced after media cleanup and restores profile state');
  console.log('PASS: recursively lists nested media and paginates beyond 100 entries');
  console.log('PASS: profile is locked before cleanup; storage removals are batched and only caller UUID folder is targeted');
  console.log('PASS: second sweep catches uploads already in flight during profile lock');
  console.log('PASS: unsafe storage entry names fail closed');
  console.log('PASS: unsupported HTTP methods are rejected');
  console.log('PASS: CORS allowlist accepts mindRID origins and omits untrusted origins');
}

run().catch((err) => { console.error(err); process.exitCode = 1; });
