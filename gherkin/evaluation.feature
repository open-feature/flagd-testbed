@rpc @in-process @file
Feature: flagd evaluations

  # This test suite contains scenarios to test flagd providers.
  # It's associated with the flags configured in flags.
  # It should be used in conjunction with the suites supplied by the OpenFeature specification.

  Background:
    Given an option "cache" of type "CacheType" with value "disabled"
    And a stable flagd provider

  Scenario Outline: Resolve values
    Given a <type>-flag with key "<key>" and a default value "<default>"
    When the flag was evaluated with details
    Then the resolved details value should be "<resolved_value>"

    Examples:
      | key          | type    | default | resolved_value |
      | boolean-flag | Boolean | false   | true           |
      | string-flag  | String  | bye     | hi             |
      | integer-flag | Integer | 1       | 10             |
      | float-flag   | Float   | 0.1     | 0.5            |

  Scenario Outline: Resolves zero value
    Given a <type>-flag with key "<key>" and a default value "<default>"
    When the flag was evaluated with details
    Then the resolved details value should be "<resolved_value>"
    And the reason should be "STATIC"

    Examples:
      | key               | type    | default | resolved_value |
      | boolean-zero-flag | Boolean | true    | false          |
      | string-zero-flag  | String  | hi      |                |
      | integer-zero-flag | Integer | 1       | 0              |
      | float-zero-flag   | Float   | 0.1     | 0.0            |

  @targeting
  Scenario Outline: Resolves zero value with targeting
    Given a <type>-flag with key "<key>" and a default value "<default>"
    And a context containing a key "email", with type "String" and with value "ballmer@macrosoft.com"
    When the flag was evaluated with details
    Then the resolved details value should be "<resolved_value>"
    And the reason should be "TARGETING_MATCH"

    Examples:
      | key                        | type    | default | resolved_value |
      | boolean-targeted-zero-flag | Boolean | true    | false          |
      | string-targeted-zero-flag  | String  | hi      |                |
      | integer-targeted-zero-flag | Integer | 1       | 0              |
      | float-targeted-zero-flag   | Float   | 0.1     | 0.0            |

  @targeting
  Scenario Outline: Resolves zero value with targeting using default
    Given a <type>-flag with key "<key>" and a default value "<default>"
    And a context containing a key "email", with type "String" and with value "ballmer@none.com"
    When the flag was evaluated with details
    Then the resolved details value should be "<resolved_value>"
    And the reason should be "DEFAULT"

    Examples:
      | key                        | type    | default | resolved_value |
      | boolean-targeted-zero-flag | Boolean | true    | false          |
      | string-targeted-zero-flag  | String  | hi      |                |
      | integer-targeted-zero-flag | Integer | 1       | 0              |
      | float-targeted-zero-flag   | Float   | 0.1     | 0.0            |
