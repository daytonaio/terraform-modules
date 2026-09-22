# Migrating a region created before `snapshot_manager_url` was required

`snapshot_manager_url` is now required and is sent in the region registration request. This affects
regions **already created** by this module, because the registration resource keeps
`ignore_changes = [headers, request_body]`.

That `ignore_changes` is deliberate: `POST /regions` is not idempotent, so replaying it would register a
second region. The consequence is that **setting the Terraform variable does not backfill
`snapshotManagerUrl` on an existing API region** — the field stays null until it is patched directly.

## Why it matters now

Registry resolution no longer falls back to the shared platform registry for a custom region. A region
whose `snapshotManagerUrl` is null therefore resolves no registry at all, and snapshot operations fail
closed rather than silently using someone else's registry. Patch existing regions before or alongside that
rollout.

## Before you patch: inventory what the region already references

Changing the recorded URL repoints where the region resolves snapshots. It does **not** move anything.
Existing snapshots and backups stay where they are, and a sandbox whose backup lives in the previous
registry will not find it under the new one.

Check what is referenced before changing anything, and plan a copy if images must survive the move.

## Patch and verify

```bash
REGION_ID="…"                       # the region created by this module
DAYTONA_API_URL="https://…/api"     # same base URL the module is configured with
DAYTONA_API_KEY="…"                 # authorized for the organization that owns the region

curl -sS -X PATCH "$DAYTONA_API_URL/regions/$REGION_ID" \
  -H "Authorization: Bearer $DAYTONA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"snapshotManagerUrl":"https://snapshots.example.com"}'

# read back and confirm the recorded value
curl -sS "$DAYTONA_API_URL/regions/$REGION_ID" \
  -H "Authorization: Bearer $DAYTONA_API_KEY" | jq -r '.snapshotManagerUrl'
```

Use the same URL you set in `snapshot_manager_url`, so Terraform state and the API agree.

## Upgrade checklist

1. Set `snapshot_manager_url` in your tfvars. Omitting it, or passing an explicit `null` or an empty
   string, now fails at plan time rather than silently skipping the registry.
2. `terraform plan` — expect **no destruction** of the snapshot-manager ECS service, ALB or S3 bucket.
   `deploy_snapshot_manager` remains `true`, so resource addresses and counts are unchanged. If a plan
   shows those resources being removed, stop and investigate before applying.
3. Confirm no second region is registered: the registration resource is unchanged and still ignores
   `request_body`.
4. PATCH the existing region as above and read the value back.
5. Verify the registry is actually reachable from the runners and that a push and pull succeed before
   treating the region as ready.
