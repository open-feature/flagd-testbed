@disabled
Feature: Evaluator disabled flag evaluation

  # Validates that disabled flags resolve with reason=DISABLED and no value/variant.
  # The evaluator omits value and variant; the SDK substitutes the caller-provided default.
  # Flags are configured in evaluator/flags/testkit-flags.json.
  # Relates to: https://github.com/open-feature/flagd/issues/1965

  Scenario Outline: Resolve disabled flag returns reason DISABLED with absent value
    Given an evaluator
    And a <type>-flag with key "<key>" and a fallback value "<default>"
    When the flag was evaluated with details
    Then the resolved value should be absent
    And the reason should be "DISABLED"

    Examples: Boolean evaluations
      | key                   | type    | default |
      | disabled-boolean-flag | Boolean | false   |

    Examples: String evaluations
      | key                  | type   | default |
      | disabled-string-flag | String | bye     |

    Examples: Number evaluations
      | key                   | type    | default |
      | disabled-integer-flag | Integer | 1       |
      | disabled-float-flag   | Float   | 0.1     |

    Examples: Object evaluations
      | key                  | type   | default |
      | disabled-object-flag | Object | {}      |
