@in-process @offline
Feature: in-process offline file functionality

  Background:
    Given a offline flagd provider

  Scenario Outline: Resolve offline values
    Given a <type>-flag with key "<key>" and a default value "<default>"
    When the flag was evaluated with details
    Then the resolved details value should be "<resolved_value>"
    Examples:
      | key          | type    | default | resolved_value |
      | boolean-flag | Boolean | false   | true           |
      | string-flag  | String  | bye     | hi             |
      | integer-flag | Integer | 1       | 10             |
      | float-flag   | Float   | 0.1     | 0.5            |

  Scenario Outline: Resolves offline zero values
    Given a <type>-flag with key "<key>" and a default value "<default>"
    When the flag was evaluated with details
    Then the resolved details value should be "<resolved_value>"

    Examples:
      | key               | type    | default | resolved_value |
      | boolean-zero-flag | Boolean | true    | false          |
      | string-zero-flag  | String  | hi      |                |
      | integer-zero-flag | Integer | 1       | 0              |
      | float-zero-flag   | Float   | 0.1     | 0.0            |
