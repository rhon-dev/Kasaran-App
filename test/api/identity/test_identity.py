"""Local-only synthetic identity/RLS integration checks. Run from repository root."""
import json
import os
import datetime
import concurrent.futures
import hashlib
import secrets
import subprocess
import unittest
import urllib.error
import urllib.request
import uuid

BASE = 'http://127.0.0.1:54321'


def request(method, path, key, bearer=None, data=None, headers=None):
    payload = None if data is None else json.dumps(data).encode()
    h = {'apikey': key, 'Content-Type': 'application/json'}
    if bearer:
        h['Authorization'] = 'Bearer ' + bearer
    h.update(headers or {})
    req = urllib.request.Request(BASE + path, payload, h, method=method)
    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            return response.status, json.loads(response.read() or b'null')
    except urllib.error.HTTPError as error:
        return error.code, json.loads(error.read() or b'null')


class Identity(unittest.TestCase):
    plan_a = None
    @classmethod
    def setUpClass(cls):
        status = json.loads(subprocess.check_output(['supabase', 'status', '-o', 'json'], stderr=subprocess.DEVNULL))
        cls.anon = status['ANON_KEY']
        cls.service = status['SERVICE_ROLE_KEY']
        cls.created = []
        cls.actors = []
        for confirmed in (True, True, True, True):
            email = 'synthetic-' + uuid.uuid4().hex + '@example.test'
            password = secrets.token_urlsafe(32) + 'aA1'
            code, user = request('POST', '/auth/v1/admin/users', cls.service, cls.service,
                                 {'email': email, 'password': password, 'email_confirm': confirmed})
            if code not in (200, 201):
                raise RuntimeError('Local synthetic Auth provisioning failed (status %s)' % code)
            cls.created.append(user['id'])
            code, token = request('POST', '/auth/v1/token?grant_type=password', cls.anon,
                                  data={'email': email, 'password': password})
            cls.actors.append({'id': user['id'], 'token': token.get('access_token') if code == 200 else None})
        # Local-only: simulate an issued access token whose account becomes unverified.
        env = dict(os.environ, PGPASSWORD='postgres')
        subprocess.run(['psql', '-X', '-q', '-v', 'ON_ERROR_STOP=1', '-h', '127.0.0.1',
                        '-p', '54322', '-U', 'postgres', '-d', 'postgres', '-c',
                        "update auth.users set email_confirmed_at = null where id = '%s'" % cls.actors[3]['id']],
                       env=env, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    @classmethod
    def tearDownClass(cls):
        # Auth FKs are intentionally restrictive; remove only rows from this run.
        ids = ','.join("'%s'" % uid for uid in cls.created)
        sql = ("begin; delete from public.invites where inviter_user_id in (%s); "
               "delete from public.plan_members where user_id in (%s); "
               "delete from public.plan_member_aliases where user_id in (%s); "
               "delete from public.plans where creator_user_id in (%s); "
               "delete from public.users where id in (%s); commit;" %
               (ids, ids, ids, ids, ids))
        subprocess.run(['psql', '-X', '-q', '-v', 'ON_ERROR_STOP=1', '-h', '127.0.0.1',
                        '-p', '54322', '-U', 'postgres', '-d', 'postgres', '-c', sql],
                       env=dict(os.environ, PGPASSWORD='postgres'), check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        for uid in cls.created:
            code, _ = request('DELETE', '/auth/v1/admin/users/' + uid, cls.service, cls.service)
            if code not in (200, 204):
                raise RuntimeError('Synthetic Auth cleanup failed (status %s)' % code)

    def call(self, actor, function, data):
        return request('POST', '/rest/v1/rpc/' + function, self.anon, actor['token'], data)

    def test_10_create_plan_requires_verified_email_and_creates_membership(self):
        creator, _, _, unverified = self.actors
        args = {'p_id': str(uuid.uuid4()), 'p_wedding_date': '2027-06-01',
                'p_total_budget_cents': 100000, 'p_guest_cap': 20,
                'p_region_code': 'PH-NCR', 'p_ruleset_version': 'synthetic',
                'p_driving_rsvp_status': 'unknown'}
        self.assertIsNotNone(unverified['token'], 'local unverified sign-in must be testable')
        status, _ = self.call(unverified, 'create_plan', args)
        self.assertGreaterEqual(status, 400)
        status, result = self.call(creator, 'create_plan', args)
        self.assertEqual(status, 200, 'create_plan HTTP status')
        self.assertEqual(result['id'], args['p_id'])
        type(self).plan_a = args['p_id']
        status, members = request('GET', '/rest/v1/plan_members?select=plan_id,user_id&plan_id=eq.' + args['p_id'],
                                  self.anon, creator['token'])
        self.assertEqual(status, 200)
        self.assertEqual(len(members), 1)
        self.assertEqual(members[0]['user_id'], creator['id'])

    def test_20_second_plan_and_direct_writes_denied(self):
        creator, partner, outsider, _ = self.actors
        status, _ = self.call(creator, 'create_plan', {
            'p_id': str(uuid.uuid4()), 'p_wedding_date': '2027-07-01',
            'p_total_budget_cents': 100000, 'p_guest_cap': 10,
            'p_region_code': 'PH-NCR', 'p_ruleset_version': 'synthetic',
            'p_driving_rsvp_status': 'unknown'})
        self.assertGreaterEqual(status, 400)
        for table, row in (
            ('plans', {'id': str(uuid.uuid4()), 'creator_user_id': outsider['id'],
                       'wedding_date': '2027-07-01', 'total_budget_cents': 10,
                       'guest_cap': 1, 'region_code': 'PH-NCR',
                       'ruleset_version': 'synthetic', 'driving_rsvp_status': 'unknown'}),
            ('plan_members', {'plan_id': self.plan_a, 'user_id': partner['id'],
                              'plan_member_id': str(uuid.uuid4()), 'role': 'partner'}),
            ('plan_member_aliases', {'plan_id': self.plan_a, 'user_id': partner['id']}),
            ('invites', {'plan_id': self.plan_a, 'inviter_user_id': creator['id'],
                         'token_hash': 'a' * 64, 'expires_at': '2027-01-01T00:00:00Z'}),
        ):
            with self.subTest(table=table):
                status, _ = request('POST', '/rest/v1/' + table, self.anon, outsider['token'], row)
                self.assertGreaterEqual(status, 400)

    def test_30_cross_tenant_reads_writes_and_rpc_guards(self):
        creator, partner, outsider, _ = self.actors
        status, second = self.call(outsider, 'create_plan', {
            'p_id': str(uuid.uuid4()), 'p_wedding_date': '2027-07-01',
            'p_total_budget_cents': 100000, 'p_guest_cap': 10,
            'p_region_code': 'PH-NCR', 'p_ruleset_version': 'synthetic',
            'p_driving_rsvp_status': 'unknown'})
        self.assertEqual(status, 200)
        other_plan = second['id']
        for table in ('plans', 'plan_members', 'plan_member_aliases', 'invites'):
            field = 'id' if table == 'plans' else 'plan_id'
            for actor, target in ((creator, other_plan), (outsider, self.plan_a)):
                with self.subTest(table=table, actor=actor['id']):
                    status, rows = request('GET', '/rest/v1/' + table + '?select=' + field + '&' + field + '=eq.' + target,
                                           self.anon, actor['token'])
                    self.assertEqual(status, 200)
                    self.assertEqual(rows, [])
                    for method in ('PATCH', 'DELETE'):
                        status, _ = request(method, '/rest/v1/' + table + '?' + field + '=eq.' + target,
                                            self.anon, actor['token'], {'is_active': False} if method == 'PATCH' else None)
                        self.assertGreaterEqual(status, 400)
        for actor, target in ((creator, other_plan), (outsider, self.plan_a)):
            status, _ = self.call(actor, 'issue_invite', {'p_plan_id': target})
            self.assertGreaterEqual(status, 400)
        status, rows = request('GET', '/rest/v1/plans?select=id', self.anon, partner['token'])
        self.assertEqual((status, rows), (200, []))

    def test_35_expired_invite_rejected(self):
        creator, partner, _, _ = self.actors
        status, issued = self.call(creator, 'issue_invite', {'p_plan_id': self.plan_a})
        self.assertEqual(status, 200)
        sql = ("update public.invites set issued_at = now() - interval '8 days', "
               "expires_at = now() - interval '1 day' where id = '%s'" % issued['id'])
        subprocess.run(['psql', '-X', '-q', '-v', 'ON_ERROR_STOP=1', '-h', '127.0.0.1',
                        '-p', '54322', '-U', 'postgres', '-d', 'postgres', '-c', sql],
                       env=dict(os.environ, PGPASSWORD='postgres'), check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        status, _ = self.call(partner, 'accept_invite', {'p_token': issued['token']})
        self.assertGreaterEqual(status, 400)

    def test_36_anonymous_cannot_invoke_rpc(self):
        for rpc, args in (('create_plan', {'p_id': str(uuid.uuid4()),
                                          'p_wedding_date': '2027-06-01',
                                          'p_total_budget_cents': 10, 'p_guest_cap': 1,
                                          'p_region_code': 'PH-NCR', 'p_ruleset_version': 'synthetic',
                                          'p_driving_rsvp_status': 'unknown'}),
                          ('issue_invite', {'p_plan_id': self.plan_a}),
                          ('accept_invite', {'p_token': '0' * 32}),
                          ('revoke_invite', {'p_invite_id': str(uuid.uuid4())})):
            with self.subTest(rpc=rpc):
                status, _ = request('POST', '/rest/v1/rpc/' + rpc, self.anon, data=args)
                self.assertGreaterEqual(status, 400)

    def test_37_rls_forced_on_every_identity_table(self):
        query = ("select coalesce(json_agg(json_build_object('name',relname,'enabled',relrowsecurity,"
                 "'forced',relforcerowsecurity)), '[]') "
                 "from pg_class where relnamespace='public'::regnamespace "
                 "and relname in ('users','plans','plan_member_aliases','plan_members','invites')")
        result = subprocess.check_output(['psql', '-X', '-A', '-t', '-h', '127.0.0.1',
                                          '-p', '54322', '-U', 'postgres', '-d', 'postgres',
                                          '-c', query], env=dict(os.environ, PGPASSWORD='postgres'))
        rows = json.loads(result.decode())
        self.assertEqual(len(rows), 5)
        self.assertTrue(all(row['enabled'] and row['forced'] for row in rows))

    def test_37b_reminder_offsets_reject_invalid_values(self):
        plan_id = self.plan_a
        if plan_id is None:
            plan_id = str(uuid.uuid4())
            status, _ = self.call(self.actors[0], 'create_plan', {
                'p_id': plan_id, 'p_wedding_date': '2027-06-01',
                'p_total_budget_cents': 100000, 'p_guest_cap': 20,
                'p_region_code': 'PH-NCR', 'p_ruleset_version': 'synthetic',
                'p_driving_rsvp_status': 'unknown'})
            self.assertEqual(status, 200)
        for value in ('[7,7]', '[-1,1]', '["tomorrow",1]', '{}'):
            with self.subTest(value=value):
                sql = ("begin; update public.plans set reminder_days_before = '%s'::jsonb "
                       "where id = '%s'; rollback;" % (value, plan_id))
                result = subprocess.run(
                    ['psql', '-X', '-q', '-v', 'ON_ERROR_STOP=1', '-h', '127.0.0.1',
                     '-p', '54322', '-U', 'postgres', '-d', 'postgres', '-c', sql],
                    env=dict(os.environ, PGPASSWORD='postgres'),
                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                self.assertNotEqual(result.returncode, 0)

    def test_37c_definers_have_locked_search_paths_and_no_anon_execute(self):
        query = ("select coalesce(json_agg(json_build_object('name',proname,"
                 "'definer',prosecdef,'config',proconfig,"
                 "'anon',has_function_privilege('anon',oid,'EXECUTE'))), '[]') "
                 "from pg_proc where pronamespace='public'::regnamespace "
                 "and proname in ('identity_auth_user','identity_auth_user_changed',"
                 "'identity_member','identity_verified','create_plan','issue_invite',"
                 "'accept_invite','revoke_invite')")
        result = subprocess.check_output(
            ['psql', '-X', '-A', '-t', '-h', '127.0.0.1', '-p', '54322',
             '-U', 'postgres', '-d', 'postgres', '-c', query],
            env=dict(os.environ, PGPASSWORD='postgres'))
        rows = json.loads(result.decode())
        self.assertEqual(len(rows), 8)
        for row in rows:
            with self.subTest(function=row['name']):
                self.assertTrue(row['definer'])
                self.assertIn('search_path=""', row['config'])
                self.assertFalse(row['anon'])

    def test_38_auth_email_change_updates_public_identity(self):
        # A server-side Auth email change must not leave stale identity data.
        actor = self.actors[2]
        new_email = 'synthetic-' + uuid.uuid4().hex + '@example.test'
        status, _ = request('PUT', '/auth/v1/admin/users/' + actor['id'],
                            self.service, self.service,
                            {'email': new_email, 'email_confirm': True})
        self.assertEqual(status, 200)
        status, rows = request('GET', '/rest/v1/users?select=email&id=eq.' + actor['id'],
                               self.anon, actor['token'])
        self.assertEqual(status, 200)
        self.assertEqual(rows, [{'email': new_email}])

    def test_40_issue_revoke_accept_and_single_use(self):
        creator, partner, outsider, unverified = self.actors
        status, issued = self.call(creator, 'issue_invite', {'p_plan_id': self.plan_a})
        self.assertEqual(status, 200)
        token = issued['token']
        self.assertEqual(len(token), 32)
        expiry = datetime.datetime.strptime(issued['expires_at'].replace('Z', '+00:00'),
                                            '%Y-%m-%dT%H:%M:%S.%f%z')
        status, invite_rows = request('GET', '/rest/v1/invites?select=issued_at&id=eq.' + issued['id'],
                                      self.anon, creator['token'])
        self.assertEqual(status, 200)
        self.assertEqual(expiry - datetime.datetime.strptime(
            invite_rows[0]['issued_at'].replace('Z', '+00:00'), '%Y-%m-%dT%H:%M:%S.%f%z'),
            datetime.timedelta(days=7))
        self.assertEqual(set(token) <= set('0123456789abcdef'), True)
        stored = subprocess.check_output(
            ['psql', '-X', '-A', '-t', '-h', '127.0.0.1', '-p', '54322',
             '-U', 'postgres', '-d', 'postgres', '-c',
             "select token_hash from public.invites where id = '%s'" % issued['id']],
            env=dict(os.environ, PGPASSWORD='postgres')).decode().strip()
        self.assertEqual(stored, hashlib.sha256(token.encode()).hexdigest())
        self.assertNotEqual(stored, token)
        status, _ = request('GET', '/rest/v1/invites?select=token_hash', self.anon, creator['token'])
        self.assertGreaterEqual(status, 400)
        status, rows = request('GET', '/rest/v1/invites?select=id,plan_id', self.anon, creator['token'])
        self.assertEqual(status, 200)
        self.assertIn(issued['id'], [row['id'] for row in rows])
        status, _ = self.call(unverified, 'accept_invite', {'p_token': token})
        self.assertGreaterEqual(status, 400)
        status, revoked = self.call(creator, 'revoke_invite', {'p_invite_id': issued['id']})
        self.assertEqual(status, 200)
        self.assertEqual(revoked['revoked'], True)
        status, _ = self.call(partner, 'accept_invite', {'p_token': token})
        self.assertGreaterEqual(status, 400)
        status, fresh = self.call(creator, 'issue_invite', {'p_plan_id': self.plan_a})
        self.assertEqual(status, 200)
        status, result = self.call(partner, 'accept_invite', {'p_token': fresh['token']})
        self.assertEqual(status, 200)
        self.assertEqual(result['plan_id'], self.plan_a)
        status, _ = self.call(partner, 'accept_invite', {'p_token': fresh['token']})
        self.assertGreaterEqual(status, 400)
        status, _ = self.call(creator, 'issue_invite', {'p_plan_id': self.plan_a})
        self.assertGreaterEqual(status, 400)
        status, _ = self.call(outsider, 'accept_invite', {'p_token': fresh['token']})
        self.assertGreaterEqual(status, 400)
        for actor in (creator, partner):
            status, rows = request('GET', '/rest/v1/plan_members?select=user_id&plan_id=eq.' + self.plan_a,
                                   self.anon, actor['token'])
            self.assertEqual(status, 200)
            self.assertEqual(len(rows), 2)
    def test_41_concurrent_distinct_invites_admit_only_one_partner(self):
        def provision():
            email = 'synthetic-' + uuid.uuid4().hex + '@example.test'
            password = secrets.token_urlsafe(32) + 'aA1'
            code, user = request('POST', '/auth/v1/admin/users', self.service, self.service,
                                 {'email': email, 'password': password, 'email_confirm': True})
            self.assertIn(code, (200, 201))
            type(self).created.append(user['id'])
            code, session = request('POST', '/auth/v1/token?grant_type=password', self.anon,
                                    data={'email': email, 'password': password})
            self.assertEqual(code, 200)
            return {'id': user['id'], 'token': session['access_token']}

        owner, candidate_a, candidate_b = (provision() for _ in range(3))
        plan_id = str(uuid.uuid4())
        status, _ = self.call(owner, 'create_plan', {
            'p_id': plan_id, 'p_wedding_date': '2027-07-01',
            'p_total_budget_cents': 100000, 'p_guest_cap': 10,
            'p_region_code': 'PH-NCR', 'p_ruleset_version': 'synthetic',
            'p_driving_rsvp_status': 'unknown'})
        self.assertEqual(status, 200)
        invites = []
        for _ in range(2):
            status, result = self.call(owner, 'issue_invite', {'p_plan_id': plan_id})
            self.assertEqual(status, 200)
            invites.append(result)
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
            futures = [executor.submit(self.call, actor, 'accept_invite',
                                       {'p_token': invite['token']})
                       for actor, invite in zip((candidate_a, candidate_b), invites)]
            statuses = [future.result()[0] for future in futures]
        self.assertEqual(sum(status == 200 for status in statuses), 1)
        self.assertEqual(sum(status >= 400 for status in statuses), 1)
        status, members = request('GET', '/rest/v1/plan_members?select=user_id&plan_id=eq.' + plan_id,
                                  self.anon, owner['token'])
        self.assertEqual(status, 200)
        self.assertEqual(len(members), 2)


if __name__ == '__main__':
    unittest.main()
