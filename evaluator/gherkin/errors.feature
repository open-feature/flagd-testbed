Feature: Evaluator error handling

  # Validates that the evaluator returns the correct error codes for
  # well-known error conditions: FLAG_NOT_FOUND and TYPE_MISMATCH.
  # Flags are configured in evaluator/flags/testkit-flags.json.

  Background:
    Given an evaluator

  Scenario: Flag not found
    Given a String-flag with key "missing-flag" and a fallback value "uh-oh"
    When the flag was evaluated with details
    Then the error-code should be "FLAG_NOT_FOUND"

  Scenario: Type mismatch
    Given a Integer-flag with key "wrong-flag" and a fallback value "13"
    When the flag was evaluated with details
    Then the error-code should be "TYPE_MISMATCH"

  @type-mismatch
  Scenario Outline: Type mismatch across the value types
    # Numeric coercion is deliberately absent: whether 0.5 may be narrowed to an integer is
    # unsettled (https://github.com/open-feature/spec/issues/430) and flagd's own ADR permits
    # coercion when it is lossless, so an integer/float row would assert a rule that does not
    # exist yet.
    Given a <type>-flag with key "<key>" and a fallback value "<default>"
    When the flag was evaluated with details
    Then the resolved details value should be "<default>"
    And the error-code should be "TYPE_MISMATCH"

    Examples: a boolean flag requested as something else
      # The two numeric rows catch a language where the boolean type is a subtype of the integer
      # type, as it is in Python: isinstance(True, int) is True, so a naive check admits a
      # boolean and the caller is handed 1 or 1.0 with no error.
      | key          | type    | default  |
      | boolean-flag | String  | fallback |
      | boolean-flag | Integer | 1        |
      | boolean-flag | Float   | 0.1      |

    Examples: a string flag requested as something else
      | key         | type    | default |
      | string-flag | Boolean | false   |
      | string-flag | Integer | 1       |
      | string-flag | Float   | 0.1     |

    Examples: a numeric flag requested as a non-numeric type
      | key          | type    | default  |
      | integer-flag | Boolean | false    |
      | integer-flag | String  | fallback |
      | float-flag   | Boolean | false    |
      | float-flag   | String  | fallback |
