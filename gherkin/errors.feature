@rpc @in-process @file @type-mismatch
Feature: flagd type mismatch handling

  # Validates that asking for a flag through the wrong accessor returns the caller's default
  # with error code TYPE_MISMATCH, rather than a coerced value. A coerced value is the worst
  # failure mode a flag has: the application receives something plausible and no signal that
  # anything went wrong.
  #
  # Numeric coercion is deliberately absent. Whether 0.5 may be narrowed to an integer is
  # unsettled in the specification (https://github.com/open-feature/spec/issues/430), and
  # flagd's own ADR permits coercion when it is lossless -- so an integer/float row here would
  # assert a rule that does not exist yet. "Is a string a boolean?" has no such defence.
  #
  # It's associated with the flags configured in flags.

  Scenario Outline: Requesting the wrong type returns the default
    Given an option "cache" of type "CacheType" with value "disabled"
    And a stable flagd provider
    And a <type>-flag with key "<key>" and a default value "<default>"
    When the flag was evaluated with details
    Then the resolved details value should be "<default>"
    And the reason should be "ERROR"
    And the error-code should be "TYPE_MISMATCH"

    Examples: a string flag requested as something else
      | key         | type    | default  |
      | string-flag | Boolean | false    |
      | string-flag | Integer | 1        |
      | string-flag | Float   | 0.1      |
      | wrong-flag  | Boolean | false    |

    Examples: a boolean flag requested as something else
      # The two numeric rows are the ones that catch a language where the boolean type is a
      # subtype of the integer type, as it is in Python: isinstance(True, int) is True, so a
      # naive check admits a boolean and the caller is handed 1 or 1.0 with no error.
      | key          | type    | default  |
      | boolean-flag | String  | fallback |
      | boolean-flag | Integer | 1        |
      | boolean-flag | Float   | 0.1      |

    Examples: a numeric flag requested as a non-numeric type
      | key          | type    | default  |
      | integer-flag | Boolean | false    |
      | integer-flag | String  | fallback |
      | float-flag   | Boolean | false    |
      | float-flag   | String  | fallback |
