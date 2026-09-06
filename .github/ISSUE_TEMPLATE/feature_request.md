name: Feature request
description: Suggest an action or idea
title: "feat: "
labels: [enhancement]
body:
  - type: textarea
    id: problem
    attributes:
      label: What problem does this solve?
    validations:
      required: true
  - type: textarea
    id: proposal
    attributes:
      label: What do you propose?
    validations:
      required: true
  - type: textarea
    id: alternatives
    attributes:
      label: Alternatives considered
    validations:
      required: false
