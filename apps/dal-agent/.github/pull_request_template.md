## Summary
- What changed & why

## DB Operations (check all)
- [ ] Ran `make migrate FILE=...` or `bruno run ...`
- [ ] Ran `make doc-sync`
- [ ] `docs/DB_CHANGELOG.md` updated by script
- [ ] `docs/SCHEMA/*` regenerated

## Validations
- [ ] `make doctor` passed
- [ ] Flat view rows > 0
- [ ] Brand mapping missing CategoryCode reduced or same

## Testing
- [ ] All tests pass
- [ ] No breaking changes to existing APIs
- [ ] Performance impact assessed

## Security
- [ ] No credentials in code or logs
- [ ] Secrets managed via Keychain/environment variables only