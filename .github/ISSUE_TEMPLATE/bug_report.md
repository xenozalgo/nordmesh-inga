---
name: Bug report
about: Create a report to help us improve
title: ''
labels: bug, help wanted
assignees: ''
---
### Before submitting review:
### - [Troubleshooting](https://github.com/bubuntux/nordvpn/wiki/Troubleshooting) 
### - [Open/Closed Issues](https://github.com/bubuntux/nordvpn/issues?q=)
### - [Discussions](https://github.com/bubuntux/nordvpn/discussions) 
### Consider creating a thread in the discussion section, specially if you don't know what the problem is or is not directly related to the image itself.

**Describe the bug**
A clear and concise description of what the bug is.

**To Reproduce using docker CLI**
Full command needs to be provided (hide credentials)
`docker run ... bubuntux/nordvpn `

**To Reproduce without docker CLI**
docker-compose.yml if used  (hide credentials)
```
version: '3'
services:
  vpn:
    image: bubuntux/nordvpn
  ...
```

**Expected behavior**
A clear and concise description of what you expected to happen and a simple way for someone else to test it.

**Logs**
Add DEBUG=trace and copy the logs here (make sure to remove you user and password from the logs as well).

**Additional context**
Distribution used, versions, architecture and any other context about the problem here.
