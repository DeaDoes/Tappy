name: Bug report
description: Something knocked wrong
title: "fix: "
labels: [bug]
body:
  - type: textarea
    id: what
    attributes:
      label: What happened?
      description: What you knocked vs what happened (or didn't).
    validations:
      required: true
  - type: textarea
    id: steps
    attributes:
      label: Steps to reproduce
    validations:
      required: false
  - type: input
    id: macos
    attributes:
      label: macOS version
    validations:
      required: true
  - type: input
    id: model
    attributes:
      label: Mac model
      description: e.g. MacBook Pro 14" M3. Knock detection is hardware-sensitive.
    validations:
      required: true
  - type: textarea
    id: extra
    attributes:
      label: Extra context
      description: Did the menu bar icon show Ready? Any logs?
    validations:
      required: false
