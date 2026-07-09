# 08-evidence/schema — Evidence Schema Reference

This directory contains **test fixtures** for the evidence record schema. The canonical evidence record schema is at `../../schemas/evidence.schema.json`, not in this directory.

## Contents

| File | Purpose |
|---|---|
| `test-fixtures/valid-pass.yaml` | Valid evidence record with result: pass |
| `test-fixtures/valid-fail.yaml` | Valid evidence record with result: fail |
| `test-fixtures/valid-waived.yaml` | Valid evidence record with result: waived (includes waiver_id) |
| `test-fixtures/invalid-missing-required.yaml` | Invalid record — used to verify schema rejects missing fields |

## Schema location

```
../../schemas/evidence.schema.json
```

## Running validation

```bash
# Validate a fixture (should pass for valid-*)
check-jsonschema --schemafile ../../schemas/evidence.schema.json test-fixtures/valid-pass.yaml

# Validate the invalid fixture (should FAIL — this is the expected behaviour)
check-jsonschema --schemafile ../../schemas/evidence.schema.json test-fixtures/invalid-missing-required.yaml
```
