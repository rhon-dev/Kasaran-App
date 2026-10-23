"""Real disposable Supabase transport integration; Python stdlib only.
Run: SUPABASE_WORKDIR=<scratch project> python3 -m unittest discover -s test/api/sync -v
Credentials remain in process memory. No hosted endpoints or simulator.
"""
import copy
import json
import os
from pathlib import Path
import subprocess
import unittest
import urllib.request
import urllib.error
import uuid


def uid():
    value = uuid.uuid4().hex
    return str(uuid.UUID(value[:12] + '7' + value[13:16] + '8' + value[17:]))


class Local:
    def __init__(self):
        self.workdir = Path(os.environ['SUPABASE_WORKDIR'])
        import re
        if not re.search(r'^project_id\s*=\s*"kasaran_p08_disposable"\s*$', (self.workdir / 'supabase/config.toml').read_text(), re.M):
            raise RuntimeError('exact disposable project guard failed')
        result = subprocess.run(['supabase', 'status', '-o', 'json'], cwd=self.workdir, capture_output=True, text=True)
        if result.returncode:
            raise RuntimeError('disposable services unavailable')
        self.settings = json.loads(result.stdout)
        self.api = self.settings['API_URL']
        from urllib.parse import urlparse
        if urlparse(self.api).hostname not in ('localhost', '127.0.0.1'):
            raise RuntimeError('local only')

    def req(self, path, body=None, token=None, method='POST', raw=False):
        key = self.settings['ANON_KEY']
        headers = {'apikey': key, 'Content-Type': 'application/json'}
        if token:
            headers['Authorization'] = 'Bearer ' + token
        data = (body.encode() if raw else json.dumps(body).encode()) if body is not None else None
        req = urllib.request.Request(self.api + path, data=data, headers=headers, method=method)
        try:
            with urllib.request.urlopen(req, timeout=30) as response:
                raw = response.read()
                return response.status, json.loads(raw) if raw else None
        except urllib.error.HTTPError as error:
            try:
                body = json.loads(error.read())
            except ValueError:
                body = {}
            return error.code, body

    def sql(self, sql):
        from urllib.parse import urlparse, unquote
        url = urlparse(self.settings['DB_URL'])
        if url.hostname not in ('127.0.0.1', 'localhost'):
            raise RuntimeError('only a local database is permitted')
        env = dict(os.environ, PGPASSWORD=unquote(url.password))
        result = subprocess.run(['psql', '-XAt', '-v', 'ON_ERROR_STOP=1', '-h', url.hostname, '-p', str(url.port), '-U', url.username, '-d', url.path[1:]], input=sql, env=env, capture_output=True, text=True)
        if result.returncode:
            raise RuntimeError('local SQL failed (diagnostics withheld to protect payloads)')
        return result.stdout.strip()

    def actor(self):
        email, password = 'sync-' + uid() + '@example.test', uid() + 'Aa1!'
        status, body = self.req('/auth/v1/admin/users', {'email': email, 'password': password, 'email_confirm': True}, self.settings['SERVICE_ROLE_KEY'])
        assert status in (200, 201), 'synthetic account creation status ' + str(status)
        user = body['id']
        status, body = self.req('/auth/v1/token?grant_type=password', {'email': email, 'password': password})
        assert status == 200, 'synthetic login status ' + str(status)
        token = body['access_token']
        plan = uid()
        status, _ = self.req('/rest/v1/rpc/create_plan', {'p_id': plan, 'p_wedding_date': '2027-06-01', 'p_total_budget_cents': 100000, 'p_guest_cap': 20, 'p_region_code': 'PH-NCR', 'p_ruleset_version': 'synthetic', 'p_driving_rsvp_status': 'unknown'}, token)
        assert status == 200, 'synthetic plan status ' + str(status)
        status, rows = self.req('/rest/v1/plan_member_aliases?select=plan_member_id&plan_id=eq.' + plan, token=token, method='GET')
        assert status == 200 and len(rows) == 1
        return {'id': user, 'token': token, 'plan': plan, 'alias': rows[0]['plan_member_id']}

    def event(self, a):
        return dict(id=uid(), plan_id=a['plan'], entity_type='ledger_entries', entity_id=uid(), field_name='estimated_cents', change_group_id=None, schema_version=1, old_value=None, new_value={'value': 9007199254740993}, device_monotonic='9223372036854775807', device_id=uid(), plan_member_id=a['alias'], created_at='2026-10-20T00:00:00Z')

    def push(self, a, rows):
        return self.req('/functions/v1/sync_push', dict(protocol_version={'major': 1, 'minor': 0}, plan_id=a['plan'], rows=rows), a['token'])

    def pull(self, a, plan=None, cursor='0', limit=100):
        return self.req('/functions/v1/sync_pull', dict(protocol_version={'major': 1, 'minor': 0}, plan_id=plan or a['plan'], cursor=cursor, limit=limit), a['token'])


class TransportTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.local = Local()

    def test_cross_plan_global_id_publication_races(self):
        from concurrent.futures import ThreadPoolExecutor
        from urllib.parse import urlparse, unquote
        import time
        l = self.local
        url = urlparse(l.settings['DB_URL'])
        args = ['psql', '-XAt', '-v', 'ON_ERROR_STOP=1', '-h', url.hostname, '-p', str(url.port), '-U', url.username, '-d', url.path[1:]]
        env = dict(os.environ, PGPASSWORD=unquote(url.password))
        def wait(query):
            deadline = time.monotonic() + 15
            while time.monotonic() < deadline:
                if l.sql(query) == '1':
                    return
                time.sleep(0.03)
            self.fail('cross-plan transaction barrier not reached')
        for window in ('committed_before_lookup', 'uncommitted_at_insert'):
            with self.subTest(window=window):
                a, b = l.actor(), l.actor()
                first, collision = l.event(a), l.event(a)
                other = dict(l.event(b), id=collision['id'])
                gate_id = int(uuid.uuid4().hex[:7], 16)
                suffix = uuid.uuid4().hex
                function = 'p08_barrier_' + suffix
                trigger = 'p08_trigger_' + suffix
                name = 'p08_collision_' + suffix
                processes = []
                def start(sql):
                    proc = subprocess.Popen(args, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env, text=True)
                    processes.append(proc)
                    proc.stdin.write(sql + '\n')
                    proc.stdin.flush()
                    return proc
                try:
                    # Test-only trigger pauses A AFTER every row's preflight but
                    # BEFORE the first publication. Scope to this synthetic ID.
                    l.sql(f"create function public.{function}() returns trigger language plpgsql as $$ begin if new.id='{first['id']}'::uuid then perform pg_advisory_xact_lock({gate_id}); end if; return new; end; $$; create trigger {trigger} before insert on public.change_log for each row execute function public.{function}();")
                    gate = start(f'select pg_advisory_lock({gate_id});')
                    wait(f"select count(*) from pg_locks where locktype='advisory' and objid={gate_id} and granted;")
                    with ThreadPoolExecutor(max_workers=1) as pool:
                        result = pool.submit(l.push, a, [first, collision])
                        wait(f"select count(*) from pg_stat_activity where wait_event='advisory' and query like '%sync_push_v1%';")
                        if window == 'committed_before_lookup':
                            self.assertEqual(l.push(b, [other])[0], 200)
                        else:
                            claims = json.loads(__import__('base64').urlsafe_b64decode(b['token'].split('.')[1] + '=='))
                            payload = json.dumps(dict(protocol_version={'major': 1, 'minor': 0}, plan_id=b['plan'], rows=[other]))
                            writer = start("begin; set application_name='" + name + "'; set local role authenticated; select set_config('request.jwt.claims',$jwt$" + json.dumps(claims) + "$jwt$,true); select public.sync_push_v1($body$" + payload + "$body$);\n")
                            wait("select count(*) from pg_stat_activity where application_name='" + name + "' and state='idle in transaction';")
                            self.assertEqual(l.pull(b)[1]['rows'], [])
                        gate.stdin.write(f'select pg_advisory_unlock({gate_id});\n\\q\n')
                        gate.stdin.flush()
                        gate.wait(timeout=15)
                        if window == 'uncommitted_at_insert':
                            wait("select count(*) from pg_stat_activity where cardinality(pg_blocking_pids(pid))>0 and query like '%sync_push_v1%' and application_name <> '" + name + "';")
                            self.assertFalse(result.done())
                            writer.stdin.write('commit;\n\\q\n')
                            writer.stdin.flush()
                            writer.wait(timeout=15)
                            self.assertEqual(writer.returncode, 0)
                        status, body = result.result(timeout=20)
                    self.assertEqual((status, body), (409, {'error': 'event_conflict'}))
                    # First inserted row AND allocation must roll back with conflict.
                    self.assertEqual(l.pull(a)[1]['rows'], [])
                    self.assertEqual(l.sql("select count(*) from public.change_log where id='" + first['id'] + "';"), '0')
                    self.assertEqual(l.pull(b)[1]['rows'][0]['id'], collision['id'])
                    self.assertEqual(l.push(a, [first])[1]['accepted'][0]['server_ts'], '1')
                finally:
                    for proc in processes:
                        if proc.poll() is None:
                            proc.kill()
                        proc.communicate(timeout=10)
                    l.sql(f'drop trigger if exists {trigger} on public.change_log; drop function if exists public.{function}();')

    def test_forged_plan_pull(self):
        l = self.local
        a, b = l.actor(), l.actor()
        event = l.event(b)
        self.assertEqual(l.push(b, [event])[0], 200)
        self.assertEqual(l.pull(b)[1]['rows'][0]['id'], event['id'])
        self.assertEqual(l.pull(a, b['plan']), l.pull(a, uid()))
        self.assertEqual(l.pull(a, b['plan']), (403, {'error': 'plan_unavailable'}))
        self.assertEqual(l.pull(a)[0], 200)

    def test_batch_atomicity_conflict_and_validation(self):
        l = self.local
        a = l.actor()
        first = l.event(a)
        self.assertEqual(l.push(a, [first])[0], 200)
        conflict = dict(first, field_name='notes')
        candidate = l.event(a)
        self.assertEqual(l.push(a, [candidate, conflict])[0], 409)
        self.assertEqual(len(l.pull(a)[1]['rows']), 1)
        invalid = [
            dict(candidate, plan_id=uid()), dict(candidate, server_ts='9'),
            dict(candidate, actor_user_id=a['id']), dict(candidate, plan_member_id=uid()),
            dict(candidate, entity_type='payments'), dict(candidate, schema_version=2),
            dict(candidate, schema_version=1.0),
            dict(candidate, id=str(uuid.uuid4())), dict(candidate, entity_id=str(uuid.uuid4())),
            dict(candidate, device_monotonic='01'), dict(candidate, device_monotonic=1),
            dict(candidate, device_monotonic='9223372036854775808'),
            dict(candidate, created_at='yesterday'), dict(candidate, field_name=2),
        ]
        for index, bad in enumerate(invalid):
            if bad['id'] == candidate['id']:
                bad['id'] = uid()
            with self.subTest(case=index):
                self.assertIn(l.push(a, [candidate, bad])[0], (400, 403))
                self.assertEqual(len(l.pull(a)[1]['rows']), 1)
        for missing in ('old_value', 'new_value', 'change_group_id'):
            bad = dict(candidate)
            del bad[missing]
            self.assertEqual(l.push(a, [bad])[0], 400)
        self.assertEqual(l.push(a, [dict(candidate, id=uid()) for _ in range(101)])[0], 400)
        self.assertEqual(l.push(a, [candidate])[1]['accepted'][0]['server_ts'], '2')
        retry = l.push(a, [first])[1]
        self.assertEqual(retry['accepted'][0]['server_ts'], '1')
        self.assertEqual(retry['server_ts_high'], '2')
        # An alias existing in this plan but owned by another account is not
        # authority to author an event, even when both accounts are members.
        other = l.actor()
        alias = uid()
        l.sql("insert into public.plan_member_aliases(plan_member_id,plan_id,user_id) values ('" + alias + "','" + a['plan'] + "','" + other['id'] + "'); delete from public.plan_members where user_id='" + other['id'] + "'; insert into public.plan_members(plan_id,user_id,plan_member_id,role) values ('" + a['plan'] + "','" + other['id'] + "','" + alias + "','partner');")
        partner = dict(other, plan=a['plan'], alias=alias)
        self.assertEqual(l.pull(partner)[0], 200)
        self.assertEqual(l.push(a, [dict(l.event(a), plan_member_id=alias)])[0], 403)
        for field, value in [('old_value', {'value': 0}), ('new_value', {'value': 9007199254740994}),
                             ('device_monotonic', '1'), ('device_id', uid()),
                             ('change_group_id', uid()), ('created_at', '2026-10-21T00:00:00Z')]:
            self.assertEqual(l.push(a, [dict(first, **{field: value})])[0], 409)
        self.assertEqual(len(l.pull(a)[1]['rows']), 2)
        self.assertEqual(l.sql("select count(*) from public.ledger_entries where plan_id='" + a['plan'] + "';"), '0')

    def test_pagination_protocol_and_auth_contract(self):
        l = self.local
        a = l.actor()
        events = [l.event(a) for _ in range(3)]
        self.assertEqual(l.push(a, events)[0], 200)
        cursor = '0'
        for i in range(3):
            status, page = l.pull(a, cursor=cursor, limit=1)
            self.assertEqual(status, 200)
            self.assertEqual(page['rows'][0]['id'], events[i]['id'])
            self.assertEqual(page['has_more'], i < 2)
            self.assertGreater(int(page['next_cursor']), int(cursor))
            cursor = page['next_cursor']
        self.assertEqual(l.pull(a, cursor=cursor)[1], dict(protocol_version={'major': 1, 'minor': 0}, rows=[], next_cursor=cursor, has_more=False))
        for bad in ('-1', '00', ' 1', '1.0', '9223372036854775808', 0, None):
            self.assertEqual(l.pull(a, cursor=bad)[0], 400)
        for bad in (0, -1, 1001, 1.5, '1', None):
            self.assertEqual(l.pull(a, limit=bad)[0], 400)
        for limit in (1, 100, 1000):
            self.assertEqual(l.pull(a, limit=limit)[0], 200)
        self.assertEqual(l.push(a, [])[1]['server_ts_high'], '3')
        for operation in ('push', 'pull'):
            path = '/functions/v1/sync_' + operation
            valid = dict(protocol_version={'major': 1, 'minor': 0}, plan_id=a['plan'], rows=[], cursor='0', limit=1)
            for raw_body in ('not json', '[]', 'null'):
                self.assertEqual(l.req(path, raw_body, a['token'], raw=True)[0], 400)
            for bad in (dict(valid, plan_id='invalid'), dict(valid, plan_id=a['plan'].upper()), dict(valid, protocol_version=1)):
                self.assertEqual(l.req(path, bad, a['token'])[0], 400)
            for missing in ('plan_id', 'protocol_version'):
                bad = dict(valid)
                del bad[missing]
                self.assertEqual(l.req(path, bad, a['token'])[0], 400)
            body = dict(protocol_version={'major': 2, 'minor': 0}, plan_id=a['plan'], rows=[], cursor='0', limit=1)
            self.assertEqual(l.req(path, body, a['token']), (426, {'error': 'unsupported_protocol', 'min_supported_build': 1}))
            self.assertEqual(l.req(path, body)[0], 401)
            self.assertEqual(l.req(path, body, 'invalid.token.here')[0], 401)
            self.assertEqual(l.req(path, token=a['token'], method='GET')[0], 405)
        claims = json.loads(__import__('base64').urlsafe_b64decode(a['token'].split('.')[1] + '=='))
        self.assertLessEqual(claims['exp'] - claims['iat'], 3600)

    def test_direct_bypass_denied(self):
        l = self.local
        a = l.actor()
        event = l.event(a)
        self.assertEqual(l.push(a, [event])[0], 200)
        for token in (None, a['token']):
            for table in ('change_log', 'sync_plan_sequences'):
                for method in ('POST', 'PATCH', 'DELETE'):
                    status, _ = l.req('/rest/v1/' + table + '?plan_id=eq.' + a['plan'] if method != 'POST' else '/rest/v1/' + table,
                                      {'plan_id': a['plan']} if method != 'DELETE' else None, token, method)
                    self.assertGreaterEqual(status, 400)
        for operation in ('push', 'pull'):
            status, _ = l.req('/rest/v1/rpc/sync_' + operation + '_v1', {'payload_text': json.dumps(dict(protocol_version={'major': 1, 'minor': 0}, plan_id=uid(), rows=[], cursor='0', limit=1))}, a['token'])
            self.assertEqual(status, 403)
        self.assertEqual(l.req('/rest/v1/rpc/sync_push_v1', {'payload_text': '{}'})[0], 401)
        self.assertGreaterEqual(l.req('/rest/v1/rpc/sync_authorize_v1', {'payload': {}}, a['token'])[0], 400)
        self.assertEqual(len(l.pull(a)[1]['rows']), 1)
        self.assertEqual(l.sql("select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('sync_push_v1','sync_pull_v1','sync_authorize_v1') and p.prosecdef and p.proconfig @> array['search_path=\"\"'];"), '3')

    def test_removed_unverified_and_revoked_session(self):
        l = self.local
        a = l.actor()
        self.assertEqual(l.push(a, [l.event(a)])[0], 200)
        l.sql("update auth.users set email_confirmed_at=null where id='" + a['id'] + "';")
        self.assertEqual(l.pull(a)[0], 401)
        self.assertEqual(l.push(a, [l.event(a)])[0], 401)
        l.sql("update auth.users set email_confirmed_at=now() where id='" + a['id'] + "';")
        self.assertEqual(l.pull(a)[0], 200)
        l.sql("update auth.sessions set not_after=now()-interval '1 second' where user_id='" + a['id'] + "';")
        self.assertEqual(l.pull(a)[0], 401)
        self.assertEqual(l.push(a, [l.event(a)])[0], 401)
        l.sql("update auth.sessions set not_after=null where user_id='" + a['id'] + "';")
        self.assertEqual(l.pull(a)[0], 200)
        l.sql("delete from public.plan_members where user_id='" + a['id'] + "';")
        self.assertEqual(l.pull(a)[0], 403)
        self.assertEqual(l.push(a, [l.event(a)])[0], 403)
        # Real Auth logout revokes this session while its signed access JWT
        # still has a valid signature and an unexpired exp claim.
        self.assertEqual(l.req('/auth/v1/logout?scope=local', {}, a['token'])[0], 204)
        self.assertEqual(l.sql("select count(*) from auth.sessions where user_id='" + a['id'] + "';"), '0')
        self.assertEqual(l.pull(a)[0], 401)
        self.assertEqual(l.push(a, [l.event(a)])[0], 401)

    def test_trusted_historical_row_formats_utc_timestamp(self):
        l = self.local
        a = l.actor()
        event = l.event(a)
        event['server_ts'] = 1
        event['device_monotonic'] = 1
        status, _ = l.req('/rest/v1/change_log', event, l.settings['SERVICE_ROLE_KEY'])
        self.assertEqual(status, 201)
        status, page = l.pull(a)
        self.assertEqual(status, 200)
        self.assertRegex(page['rows'][0]['created_at'], r'^2026-10-20T00:00:00(?:\.0+)?Z$')

    def test_real_transactions_commit_order_and_rollback(self):
        from concurrent.futures import ThreadPoolExecutor
        import time
        l = self.local
        a = l.actor()
        first, second = l.event(a), l.event(a)
        claims = json.loads(__import__('base64').urlsafe_b64decode(a['token'].split('.')[1] + '=='))
        from urllib.parse import urlparse, unquote
        url = urlparse(l.settings['DB_URL'])
        env = dict(os.environ, PGPASSWORD=unquote(url.password))
        args = ['psql', '-XAt', '-v', 'ON_ERROR_STOP=1', '-h', url.hostname, '-p', str(url.port), '-U', url.username, '-d', url.path[1:]]
        processes = []
        def start(sql):
            process = subprocess.Popen(args, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env, text=True)
            processes.append(process)
            process.stdin.write(sql + '\n')
            process.stdin.flush()
            return process
        def barrier(query):
            deadline = time.monotonic() + 15
            while time.monotonic() < deadline:
                if l.sql(query) == '1':
                    return
                time.sleep(0.03)
            self.fail('database lock barrier not reached')
        gate_id = int(uuid.uuid4().hex[:7], 16)
        name = 'p08_' + uuid.uuid4().hex
        try:
            gate = start(f"select pg_advisory_lock({gate_id});")
            barrier(f"select count(*) from pg_locks where locktype='advisory' and objid={gate_id} and granted;")
            payload = json.dumps(dict(protocol_version={'major': 1, 'minor': 0}, plan_id=a['plan'], rows=[first]))
            # Claims are those of a REAL issued local Auth session, passed over stdin.
            writer = start("begin; set application_name='" + name + "'; set local role authenticated; select set_config('request.jwt.claims',$jwt$" + json.dumps(claims) + "$jwt$,true); select public.sync_push_v1($body$" + payload + f"$body$); select pg_advisory_lock({gate_id}); commit;\\q")
            barrier("select count(*) from pg_stat_activity where application_name='" + name + "' and wait_event='advisory';")
            self.assertEqual(l.pull(a)[1]['rows'], [])
            with ThreadPoolExecutor(max_workers=1) as pool:
                later = pool.submit(l.push, a, [second])
                barrier("select count(*) from pg_stat_activity where cardinality(pg_blocking_pids(pid))>0 and query like '%sync_push_v1%' and application_name <> '" + name + "';")
                self.assertFalse(later.done(), 'later acceptance must not overtake held transaction')
                self.assertEqual(l.pull(a)[1]['rows'], [])
                gate.stdin.write(f"select pg_advisory_unlock({gate_id});\n\\q\n")
                gate.stdin.flush()
                writer.wait(timeout=15)
                self.assertEqual(writer.returncode, 0)
                status, accepted = later.result(timeout=20)
                self.assertEqual(status, 200)
                self.assertEqual(accepted['accepted'][0]['server_ts'], '2')
            page = l.pull(a)[1]
            self.assertEqual([r['id'] for r in page['rows']], [first['id'], second['id']])
            rolled = l.event(a)
            payload = json.dumps(dict(protocol_version={'major': 1, 'minor': 0}, plan_id=a['plan'], rows=[rolled]))
            l.sql("begin; set local role authenticated; select set_config('request.jwt.claims',$jwt$" + json.dumps(claims) + "$jwt$,true); select public.sync_push_v1($body$" + payload + "$body$); rollback;")
            self.assertEqual(len(l.pull(a)[1]['rows']), 2)
            self.assertEqual(l.push(a, [rolled])[1]['accepted'][0]['server_ts'], '3')
        finally:
            for process in processes:
                if process.poll() is None:
                    process.kill()
                process.communicate(timeout=10)

    def test_waiting_push_rechecks_revoked_session(self):
        from concurrent.futures import ThreadPoolExecutor
        from urllib.parse import urlparse, unquote
        import time
        l = self.local
        a = l.actor()
        self.assertEqual(l.push(a, [])[0], 200)
        url = urlparse(l.settings['DB_URL'])
        args = ['psql', '-XAt', '-v', 'ON_ERROR_STOP=1', '-h', url.hostname, '-p', str(url.port), '-U', url.username, '-d', url.path[1:]]
        env = dict(os.environ, PGPASSWORD=unquote(url.password))
        name = 'p08_revocation_' + uuid.uuid4().hex
        holder = subprocess.Popen(args, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env, text=True)
        def wait(query):
            deadline = time.monotonic() + 15
            while time.monotonic() < deadline:
                if l.sql(query) == '1':
                    return
                time.sleep(0.03)
            self.fail('revocation lock barrier not reached')
        try:
            holder.stdin.write("begin; set application_name='" + name + "'; select * from public.sync_plan_sequences where plan_id='" + a['plan'] + "' for update;\n")
            holder.stdin.flush()
            wait("select count(*) from pg_stat_activity where application_name='" + name + "' and state='idle in transaction';")
            with ThreadPoolExecutor(max_workers=1) as pool:
                result = pool.submit(l.push, a, [l.event(a)])
                wait("select count(*) from pg_stat_activity where cardinality(pg_blocking_pids(pid))>0 and query like '%sync_push_v1%';")
                l.sql("delete from auth.sessions where user_id='" + a['id'] + "';")
                holder.stdin.write('rollback;\n\\q\n')
                holder.stdin.flush()
                holder.wait(timeout=15)
                self.assertEqual(result.result(timeout=20)[0], 401)
            self.assertEqual(l.sql("select count(*) from public.change_log where plan_id='" + a['plan'] + "';"), '0')
        finally:
            if holder.poll() is None:
                holder.kill()
            holder.communicate(timeout=10)

    def test_waiting_push_rechecks_naturally_expired_session(self):
        from concurrent.futures import ThreadPoolExecutor
        from urllib.parse import urlparse, unquote
        import time
        l = self.local
        a = l.actor()
        self.assertEqual(l.push(a, [])[0], 200)
        url = urlparse(l.settings['DB_URL'])
        args = ['psql', '-XAt', '-v', 'ON_ERROR_STOP=1', '-h', url.hostname, '-p', str(url.port), '-U', url.username, '-d', url.path[1:]]
        env = dict(os.environ, PGPASSWORD=unquote(url.password))
        name = 'p08_expiry_' + uuid.uuid4().hex
        holder = subprocess.Popen(args, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env, text=True)
        def wait(query):
            deadline = time.monotonic() + 15
            while time.monotonic() < deadline:
                if l.sql(query) == '1':
                    return
                time.sleep(0.03)
            self.fail('natural expiry lock barrier not reached')
        try:
            holder.stdin.write("begin; set application_name='" + name + "'; select * from public.sync_plan_sequences where plan_id='" + a['plan'] + "' for update;\n")
            holder.stdin.flush()
            wait("select count(*) from pg_stat_activity where application_name='" + name + "' and state='idle in transaction';")
            l.sql("update auth.sessions set not_after=clock_timestamp()+interval '5 seconds' where user_id='" + a['id'] + "';")
            with ThreadPoolExecutor(max_workers=1) as pool:
                result = pool.submit(l.push, a, [l.event(a)])
                wait("select count(*) from pg_stat_activity where cardinality(pg_blocking_pids(pid))>0 and query like '%sync_push_v1%';")
                # Prove this RPC began before expiry; no deletion/revocation or
                # expiry update occurs while it waits. Let wall time pass naturally.
                self.assertEqual(l.sql("select count(*) from pg_stat_activity q join auth.sessions s on s.user_id='" + a['id'] + "' where cardinality(pg_blocking_pids(q.pid))>0 and q.query like '%sync_push_v1%' and q.xact_start<s.not_after and s.not_after>clock_timestamp();"), '1')
                l.sql("select pg_sleep(greatest(0,extract(epoch from (not_after-clock_timestamp())))+0.05) from auth.sessions where user_id='" + a['id'] + "';")
                self.assertEqual(l.sql("select count(*) from auth.sessions where user_id='" + a['id'] + "' and not_after<clock_timestamp();"), '1')
                self.assertFalse(result.done())
                holder.stdin.write('rollback;\n\\q\n')
                holder.stdin.flush()
                holder.wait(timeout=15)
                self.assertEqual(result.result(timeout=20), (401, {'error': 'authentication_required'}))
            self.assertEqual(l.sql("select count(*) from public.change_log where plan_id='" + a['plan'] + "';"), '0')
            self.assertEqual(l.sql("select server_ts_high from public.sync_plan_sequences where plan_id='" + a['plan'] + "';"), '0')
        finally:
            if holder.poll() is None:
                holder.kill()
            holder.communicate(timeout=10)

    def test_exact_retry_does_not_allocate_when_sequence_exhausted(self):
        l = self.local
        a = l.actor()
        event = l.event(a)
        self.assertEqual(l.push(a, [event])[0], 200)
        l.sql("update public.sync_plan_sequences set server_ts_high=9223372036854775807 where plan_id='" + a['plan'] + "';")
        status, body = l.push(a, [event])
        self.assertEqual(status, 200)
        self.assertEqual(body['accepted'], [{'id': event['id'], 'server_ts': '1'}])
        self.assertEqual(body['server_ts_high'], '9223372036854775807')
        self.assertEqual(l.push(a, [l.event(a)])[0], 400)
        self.assertEqual(len(l.pull(a)[1]['rows']), 1)

    def test_same_batch_exact_duplicate_is_idempotent(self):
        l = self.local
        a = l.actor()
        event = l.event(a)
        status, accepted = l.push(a, [event, copy.deepcopy(event)])
        self.assertEqual(status, 200)
        self.assertEqual(accepted['accepted'], [{'id': event['id'], 'server_ts': '1'}] * 2)
        self.assertEqual(accepted['server_ts_high'], '1')
        self.assertEqual(len(l.pull(a)[1]['rows']), 1)
        conflict = dict(event, new_value={'value': 2})
        self.assertEqual(l.push(a, [event, conflict])[0], 409)

    def test_own_push_pull_exact_retry(self):
        l = self.local
        a = l.actor()
        event = l.event(a)
        status, first = l.push(a, [event])
        self.assertEqual(status, 200)
        self.assertEqual(len(first['accepted']), 1)
        self.assertRegex(first['accepted'][0]['server_ts'], r'^[1-9][0-9]*$')
        self.assertEqual(l.push(a, [event]), (200, first))
        status, page = l.pull(a, limit=1)
        self.assertEqual(status, 200)
        self.assertEqual(page['rows'][0]['new_value']['value'], 9007199254740993)
        self.assertEqual(page['rows'][0]['device_monotonic'], '9223372036854775807')
        self.assertEqual(page['next_cursor'], first['accepted'][0]['server_ts'])
        self.assertEqual(page['has_more'], False)


if __name__ == '__main__':
    unittest.main(verbosity=2)
