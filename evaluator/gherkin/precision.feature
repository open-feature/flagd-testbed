@precision
Feature: Evaluator numeric precision

  # Validates that a numeric flag value survives evaluation unrounded and unnarrowed.
  # The evaluator has no accessor types of its own, so what is under test here is narrower than
  # in the provider suite: only that the value written in the flag definition is the value that
  # comes back out.
  # Flags are configured in evaluator/flags/testkit-flags.json.

  Background:
    Given an evaluator

  Scenario Outline: Resolve numeric values without loss of precision
    Given a <type>-flag with key "<key>" and a fallback value "<default>"
    When the flag was evaluated with details
    Then the resolved details value should be "<resolved_value>"
    And the reason should be "STATIC"

    Examples: Integer evaluations
      # 2147483647 is 2^31 - 1, outside what a 32-bit float represents exactly, so a round trip
      # through one returns 2147483648.
      | key                | type    | default | resolved_value |
      | large-integer-flag | Integer | 1       | 2147483647     |

    Examples: Float evaluations
      # A float whose value is integral must stay a float rather than arriving as 10.
      | key                 | type  | default | resolved_value |
      | integral-float-flag | Float | 0.1     | 10.0           |

  @large-integers
  Scenario: Resolve an integer beyond 32 bits without loss of precision
    # 9007199254740991 is 2^53 - 1, the largest integer a double represents exactly. Tagged
    # separately because a language whose integer type is 32 bits cannot ask for it at all --
    # excluding @large-integers is the honest answer there, not failing it.
    Given a Integer-flag with key "huge-integer-flag" and a fallback value "1"
    When the flag was evaluated with details
    Then the resolved details value should be "9007199254740991"
    And the reason should be "STATIC"
