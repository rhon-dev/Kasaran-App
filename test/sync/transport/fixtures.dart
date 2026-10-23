const planId = '11111111-1111-4111-8111-111111111111';
const eventId = '019a0000-0000-7000-8000-000000000001';

Map<String, Object?> wireEvent() => {
  'id': eventId,
  'plan_id': planId,
  'entity_type': 'ledger_entries',
  'entity_id': '019a0000-0000-7000-8000-000000000002',
  'field_name': 'estimated_cents',
  'change_group_id': null,
  'schema_version': 1,
  'old_value': null,
  'new_value': {'cents': 9007199254740993},
  'device_monotonic': '9223372036854775807',
  'device_id': '22222222-2222-4222-8222-222222222222',
  'plan_member_id': '33333333-3333-4333-8333-333333333333',
  'created_at': '2026-10-20T08:00:00.000Z',
};
