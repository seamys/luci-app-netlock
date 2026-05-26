---
name: Bug Report
about: Report a bug or unexpected behavior
title: '[Bug] '
labels: bug
---

**Environment**
- OpenWrt version:
- Router model:
- NetLock version (git tag or commit):

**Describe the bug**
A clear description of what went wrong.

**Expected behavior**
What you expected to happen.

**Steps to reproduce**
1. ...
2. ...

**Diagnostic output**
```
# Paste output of:
uci show netlock
cat /var/run/netlock.json
nft list table inet netlock 2>/dev/null || echo "no rules"
logread | grep netlock | tail -20
```
