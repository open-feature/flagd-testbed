@rpc @in-process @file @targeting @resolve
Feature: Terminal resolve operator

  # This test suite contains scenarios for the terminal `resolve` operator, which ends a targeting rule with a variant,
  # and optionally a custom reason and rule-level flag metadata.
  # See https://github.com/open-feature/flagd/blob/main/docs/architecture-decisions/targeting-variant-metadata.md
  # It's associated with the flags configured in flags/resolve-flags.json.
  # Position, not operator, is terminal: the same `resolve` is valid as the whole rule or an `if` / `?:` result,
  # and makes the flag invalid anywhere its result would be consumed.

  Background:
    Given an option "cache" of type "CacheType" with value "disabled"
    And a stable flagd provider

  Scenario Outline: Resolve selects a variant with an optional reason
    Given a String-flag with key "<key>" and a default value "fallback"
    When the flag was evaluated with details
    Then the resolved details value should be "on"
    And the variant should be "on"
    And the reason should be "<reason>"
    Examples:
      | key                        | reason          |
      | resolve-whole-rule-flag    | TARGETING_MATCH |
      | resolve-custom-reason-flag | ALLOWLIST       |
      | resolve-ref-terminal-flag  | ALLOWLIST       |

  # the reason is free-form, so flagd's own reason names must not change the value or variant
  Scenario Outline: Resolve reason is free-form
    Given a String-flag with key "<key>" and a default value "fallback"
    When the flag was evaluated with details
    Then the resolved details value should be "on"
    And the variant should be "on"
    And the reason should be "<reason>"
    Examples:
      | key                          | reason   |
      | resolve-fallback-reason-flag | FALLBACK |
      | resolve-disabled-reason-flag | DISABLED |
      | resolve-error-reason-flag    | ERROR    |

  @metadata
  Scenario: Resolve with a null reason keeps the targeting match reason and adds metadata
    Given a String-flag with key "resolve-null-reason-metadata-flag" and a default value "fallback"
    When the flag was evaluated with details
    Then the resolved details value should be "on"
    And the reason should be "TARGETING_MATCH"
    And the resolved metadata should contain
      | key     | metadata_type | value        |
      | details | String        | pilot cohort |

  @metadata
  Scenario: Rule metadata overwrites flag metadata
    Given a String-flag with key "resolve-metadata-precedence-flag" and a default value "fallback"
    When the flag was evaluated with details
    Then the resolved details value should be "on"
    And the reason should be "ALLOWLIST"
    And the resolved metadata should contain
      | key     | metadata_type | value |
      | details | String        | rule  |
      | owner   | String        | flag  |

  # branches that serve the same variant stay distinguishable by reason and details
  Scenario Outline: Resolve in nested if branches
    Given a String-flag with key "resolve-nested-branches-flag" and a default value "fallback"
    And a context containing a key "customerId", with type "String" and with value "<customerId>"
    When the flag was evaluated with details
    Then the resolved details value should be "<variant>"
    And the reason should be "<reason>"
    Examples:
      | customerId | variant | reason      |
      | customer-a | on      | ALLOWLIST   |
      | customer-b | on      | SPLIT       |
      | customer-z | off     | FALLTHROUGH |

  @metadata
  Scenario Outline: Resolve in nested if branches adds the branch details
    Given a String-flag with key "resolve-nested-branches-flag" and a default value "fallback"
    And a context containing a key "customerId", with type "String" and with value "<customerId>"
    When the flag was evaluated with details
    Then the resolved metadata should contain
      | key     | metadata_type | value     |
      | details | String        | <details> |
    Examples:
      | customerId | details              |
      | customer-a | customer-a allowlist |
      | customer-b | customer-b split     |
      | customer-z | everyone else        |

  Scenario Outline: Resolve in ternary results
    Given a String-flag with key "resolve-ternary-flag" and a default value "fallback"
    And a context containing a key "customerId", with type "String" and with value "<customerId>"
    When the flag was evaluated with details
    Then the resolved details value should be "<variant>"
    And the reason should be "<reason>"
    Examples:
      | customerId | variant | reason      |
      | customer-a | on      | ALLOWLIST   |
      | customer-z | off     | FALLTHROUGH |

  Scenario Outline: Resolve with computed arguments
    Given a String-flag with key "resolve-computed-arguments-flag" and a default value "fallback"
    And a context containing a key "cohort", with type "String" and with value "<cohort>"
    When the flag was evaluated with details
    Then the resolved details value should be "<variant>"
    And the reason should be "<reason>"
    Examples:
      | cohort | variant | reason       |
      | beta   | on      | COHORT_beta  |
      | alpha  | off     | COHORT_alpha |

  @metadata
  Scenario Outline: Resolve with computed metadata
    Given a String-flag with key "resolve-computed-arguments-flag" and a default value "fallback"
    And a context containing a key "cohort", with type "String" and with value "<cohort>"
    When the flag was evaluated with details
    Then the resolved metadata should contain
      | key     | metadata_type | value     |
      | details | String        | <details> |
    Examples:
      | cohort | details      |
      | beta   | cohort beta  |
      | alpha  | cohort alpha |

  @metadata
  Scenario: Resolve with a computed number in metadata
    Given a String-flag with key "resolve-computed-number-metadata-flag" and a default value "fallback"
    And a context containing a key "hits", with type "Integer" and with value "1"
    And a context containing a key "total", with type "Integer" and with value "4"
    When the flag was evaluated with details
    Then the resolved details value should be "on"
    And the reason should be "SPLIT"
    And the resolved metadata should contain
      | key   | metadata_type | value |
      | share | Float         | 0.25  |

  # malformed computed arguments return null like the other custom operators, so the default variant is selected
  @operator-errors
  Scenario: Resolve with a computed null variant falls back to the default variant
    Given a String-flag with key "resolve-computed-null-variant-flag" and a default value "fallback"
    When the flag was evaluated with details
    Then the resolved details value should be "off"
    And the reason should be "DEFAULT"

  # NaN and Infinity can't be encoded as JSON, so they are malformed metadata values
  @operator-errors
  Scenario Outline: Resolve with a non-finite computed number in metadata falls back to the default variant
    Given a String-flag with key "resolve-computed-number-metadata-flag" and a default value "fallback"
    And a context containing a key "hits", with type "Integer" and with value "<hits>"
    And a context containing a key "total", with type "Integer" and with value "0"
    When the flag was evaluated with details
    Then the resolved details value should be "off"
    And the reason should be "DEFAULT"
    Examples:
      | hits |
      | 1    |
      | 0    |

  # variant keys are never empty, so an empty variant is missing too
  Scenario Outline: Resolve naming a missing variant fails like a plain string
    Given a String-flag with key "<key>" and a default value "fallback"
    When the flag was evaluated with details
    Then the resolved details value should be "fallback"
    And the error-code should be "GENERAL"
    Examples:
      | key                          |
      | resolve-missing-variant-flag |
      | resolve-empty-variant-flag   |

  # only the offending flag is invalid; every other flag in the same configuration still evaluates
  Scenario Outline: Resolve outside a terminal position or with malformed arguments makes the flag invalid
    Given a String-flag with key "<key>" and a default value "fallback"
    When the flag was evaluated with details
    Then the resolved details value should be "fallback"
    And the error-code should be "PARSE_ERROR"
    Examples:
      | key                              |
      | resolve-in-equality-flag         |
      | resolve-in-cat-flag              |
      | resolve-as-condition-flag        |
      | resolve-ref-consumed-flag        |
      | resolve-no-arguments-flag        |
      | resolve-non-string-variant-flag  |
      | resolve-non-string-reason-flag   |
      | resolve-short-pair-flag          |
      | resolve-non-primitive-value-flag |
