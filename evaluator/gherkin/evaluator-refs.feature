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

  # Nested $ref resolution — is_privileged references is_ballmer.
  # Use -t "not @evaluator-ref-edge-cases" to exclude during transition.
  @evaluator-ref-edge-cases
  Scenario Outline: Nested evaluator ref resolution
    Given an evaluator
    And a String-flag with key "nested-ref-targeted-flag" and a fallback value "fallback"
    And a context containing a key "<context_key>", with type "String" and with value "<context_value>"
    When the flag was evaluated with details
    Then the resolved details value should be "<value>"

    Examples:
      | context_key | context_value         | value      |
      | email       | ballmer@macrosoft.com | privileged |
      | role        | admin                 | privileged |
      | email       | other@example.com     | standard   |
