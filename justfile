# Validate manifests and skills; fails on warnings
verify:
    claude plugin validate --strict .

# Extra checks the plugin directory runs at submission (needs an icon first)
submit-check:
    claude plugin validate --strict --profile directory .
