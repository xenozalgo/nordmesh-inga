---
name: Bug report
about: Create a report to help us improve
title: ''
labels: bug, help wanted
assignees: ''

---

### Before submitting review [Troubleshooting](https://github.com/bubuntux/nordvpn/wiki/Troubleshooting) and open/closed [Issues](https://github.com/bubuntux/nordvpn/issues?q=) ###

**Describe the bug**
A clear and concise description of what the bug is.

**To Reproduce using docker CLI**
Full command needs to be provided (hide credentials)
docker run ... bubuntux/nordvpn 

**To Reproduce without docker CLI**
If using docker-compose make sure to add `network_mode: bridge`

**Expected behavior**
A clear and concise description of what you expected to happen and a simple way for someone else to test it.

**Logs**
Add DEBUG=on and copy the logs here (make sure to remove you user and password from the logs as well).

**Additional context**
Distribution used, Versions, architecture and any other context about the problem here.
