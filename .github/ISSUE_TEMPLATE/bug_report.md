---
name: Bug report
about: Create a report to help us improve
title: ''
labels: bug, help wanted
assignees: ''
---
### Before submitting review:
### - [Open/Closed Issues](https://github.com/nrdvpn/client/issues)
### - [Discussions](https://github.com/nrdvpn/client/discussions) 
### Consider creating a thread in the discussion section, specially if you don't know what the problem is or is not directly related to the image itself.

**Describe the bug**
A clear and concise description of what the bug is.

**To Reproduce using docker CLI**
Full command needs to be provided (hide credentials)
`docker run ... nrdvpn/client `

**To Reproduce using docker-compose**
docker-compose.yml if used  (hide credentials)
```
version: '3'
services:
  vpn:
    image: nrdvpn/client
  ...
```

**Expected behavior**
A clear and concise description of what you expected to happen and a simple way for someone else to test it.

**Logs**
Focus on errors or warnings messages, if not available post entire logs

**Additional context**
Distribution used, versions, architecture and any other context about the problem here.
