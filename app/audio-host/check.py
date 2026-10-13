#!/usr/bin/env python3
"""Read actual CoreAudio properties; start no audio and make no hardware writes."""
import json
from pathlib import Path
import subprocess

root = Path(__file__).parent
binary = root / 'build/audio-host'
listing = subprocess.run([str(binary), '--list'], text=True, capture_output=True, check=True)
data = json.loads(listing.stdout)
assert data['operation'] == 'read_only_inventory'
assert len(data['companion_devices']) == 2
assert {d['uid'] for d in data['companion_devices']} == {'dev.hari.labvoice.feed', 'dev.hari.labvoice.monitor'}
(root / 'build/inventory.json').write_text(listing.stdout)
for device in data['devices']:
    assert device['uid'] and device['id'] > 0
    assert device['input']['channels'] >= 0 and device['output']['channels'] >= 0
    for direction in ('input', 'output'):
        for fmt in device[direction]['current_formats']:
            assert fmt['rate'] > 0 and fmt['channels'] > 0
# Missing UID lookup is a real HAL request, not a mocked property response.
missing = subprocess.run([str(binary), '--plan', '--input', 'dev.hari.labvoice.test.missing-input', '--output', 'dev.hari.labvoice.test.missing-output'], text=True, capture_output=True)
assert missing.returncode == 2
plan = json.loads(missing.stdout)
assert plan['runnable'] is False
assert sum('Missing device UID: dev.hari.labvoice.test.' in b for b in plan['blockers']) == 2
inputs = [d for d in data['devices'] if d['input']['channels']]
outputs = [d for d in data['devices'] if d['output']['channels']]
if inputs and outputs:
    actual = subprocess.run([str(binary), '--plan', '--input', inputs[0]['uid'], '--output', outputs[0]['uid']], text=True, capture_output=True)
    assert actual.returncode == 2
    actual_plan = json.loads(actual.stdout)
    assert actual_plan['runnable'] is False
    assert len(actual_plan['hardware_adaptations']) == 2
    for adaptation in actual_plan['hardware_adaptations']:
        assert adaptation['unit_configuration_verified'] is False
        assert adaptation['adaptive_clock_bridge_required'] is True
        assert adaptation['nominal_rate_conversion_required'] == (adaptation['hardware_rate'] != 48000)
    assert inputs[0]['uid'] in {d['uid'] for d in actual_plan['resolved_devices']}
    assert outputs[0]['uid'] in {d['uid'] for d in actual_plan['resolved_devices']}
    (root / 'build/compatibility-plan.json').write_text(actual.stdout)
# The aggregate planner produces a proposal, never creates or starts a HAL object.
def aggregate(input_uid, output_uid):
    result = subprocess.run([str(binary), '--aggregate-plan', '--input', input_uid, '--output', output_uid], text=True, capture_output=True)
    assert result.returncode == 2
    plan = json.loads(result.stdout)
    assert plan['operation'] == 'read_only_private_aggregate_plan' and plan['runnable'] is False
    composition = plan['composition_proposal']
    assert composition['private'] == 1
    assert composition['master'] == 'dev.hari.labvoice.feed'
    assert composition['uid'].startswith('dev.hari.labvoice.aggregate.')
    assert len({m['uid'] for m in composition['subdevices']}) == len(composition['subdevices'])
    assert composition['subdevices'][0]['drift'] == 0
    assert all(m['drift quality'] == 96 for m in composition['subdevices'])
    assert plan['lifecycle_plan'] and plan['blockers']
    return plan

same = aggregate('dev.hari.labvoice.test.missing-hardware', 'dev.hari.labvoice.test.missing-hardware')
assert len(same['composition_proposal']['subdevices']) == 3
hardware = same['members'][-1]
assert set(hardware['roles']) == {'physical_microphone_input', 'physical_speaker_output'}
assert same['composition_proposal']['subdevices'][1]['drift'] == 1  # Clock not confirmed, safe proposal.
if inputs and outputs:
    proposal = aggregate(inputs[0]['uid'], outputs[0]['uid'])
    assert len(proposal['composition_proposal']['subdevices']) == len({inputs[0]['uid'], outputs[0]['uid'], 'dev.hari.labvoice.feed', 'dev.hari.labvoice.monitor'})
    assert all(m['drift'] == 1 for m in proposal['composition_proposal']['subdevices'][2:])
    for member in proposal['members']:
        if member['present'] and member['device']['nominal_rate'] != 48000:
            assert any(member['uid'] in b and ('not currently at that rate' in b or 'mixed-rate' in b) for b in proposal['blockers'])
    (root / 'build/aggregate-plan.json').write_text(json.dumps(proposal, indent=2) + '\n')

mismatched = [d for d in inputs if d['nominal_rate'] != 48000]
if mismatched and outputs:
    mixed = aggregate(mismatched[0]['uid'], outputs[0]['uid'])
    assert any(mismatched[0]['uid'] in b and ('not currently at that rate' in b or 'mixed-rate' in b) for b in mixed['blockers'])
    (root / 'build/mixed-rate-blocked-plan.json').write_text(json.dumps(mixed, indent=2) + '\n')

print(f"PASS: real HAL inventory: {len(data['devices'])} physical devices, {len(data['errors'])} read errors; UID lookup, blocked route plans and deduplicated private aggregate plans. No audio started.")
