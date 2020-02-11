---
name: Bug report
about: Create a report to help us improve
title: ''
labels: bug
assignees: bubuntux

---

***IMPORTANT!!! Any Bug without this format would be automatically close. ( before submitting review [Troubleshooting](https://github.com/bubuntux/nordvpn/wiki/Troubleshooting) )***

**Describe the bug**
A clear and concise description of what the bug is.

**To Reproduce using docker CLI**
Full command needs to be provided (hide credentials)
docker run ... bubuntux/nordvpn 

**To Reproduce without docker CLI**
If using docker-compose make sure to add `network_mode: bridge`

**Logs**
Add DEBUG=on and copy the logs here (make sure to remove you user and password from the logs as well).

**Additional context**
Distribution used, Versions, architecture and any other context about the problem here.
