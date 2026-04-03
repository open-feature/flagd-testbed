Feature: Evaluator evaluator refs

  # Tests that $ref shared targeting rules work correctly.

  Scenario Outline: Evaluator reuse via $ref
    Given an evaluator
    And a String-flag with key "<key>" and a fallback value "fallback"
    And a context containing a key "email", with type "String" and with value "ballmer@macrosoft.com"
    When the flag was evaluated with details
    Then the resolved details value should be "<value>"

    Examples:
      | key                            | value |
      | some-email-targeted-flag       | hi    |
      | some-other-email-targeted-flag | yes   |

  @evaluator-refs @evaluator-refs-whitespace
  Scenario Outline: Evaluator $ref resolves regardless of whitespace around the colon
    Given a String-flag with key "<key>" and a default value "fallback"
    And a context containing a key "email", with type "String" and with value "<email>"
    When the flag was evaluated with details
    Then the resolved details value should be "<value>"
    And the reason should be "TARGETING_MATCH"
    Examples:
      | key                                    | email                 | value |
      | ref-whitespace-compact-flag            | ballmer@macrosoft.com | hi    |
      | ref-whitespace-space-after-colon-flag  | ballmer@macrosoft.com | hi    |
      | ref-whitespace-space-around-colon-flag | ballmer@macrosoft.com | hi    |
      | ref-whitespace-compact-flag            | user@example.com      | bye   |
      | ref-whitespace-space-after-colon-flag  | user@example.com      | bye   |
      | ref-whitespace-space-around-colon-flag | user@example.com      | bye   |

  @evaluator-refs @non-existent-evaluator-ref
  Scenario: Ref to nonexistent evaluator yields parse error
    Given a String-flag with key "ref-to-nonexistent-evaluator-flag" and a default value "fallback"
    When the flag was evaluated with details
    Then the resolved details value should be "fallback"
    And the error-code should be "PARSE_ERROR"
    And the error message should contain "nonexistent_evaluator"
