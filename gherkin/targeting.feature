@rpc @in-process @file @targeting
Feature: Targeting rules

  # This test suite contains scenarios to test the json-evaluation of flagd and flag-in-process providers.
  # It's associated with the flags configured in flags/changing-flag.json, flags/zero-flags.json, flags/custom-ops.json and evaluator-refs.json.
  # It should be used in conjunction with the suites supplied by the OpenFeature specification.

  Background:
    Given an option "cache" of type "CacheType" with value "disabled"
    And a stable flagd provider

  # evaluator refs
  Scenario Outline: Evaluator reuse
    Given a String-flag with key "<key>" and a default value "fallback"
    And a context containing a key "email", with type "String" and with value "ballmer@macrosoft.com"
    When the flag was evaluated with details
    Then the resolved details value should be "<value>"
    Examples:
      | key                            | value |
      | some-email-targeted-flag       | hi    |
      | some-other-email-targeted-flag | yes   |

  # custom operators
  # @fractional-v1: legacy float-based bucketing (abs(hash) / i32::MAX * 100)
  # @fractional-v2: high-precision integer bucketing ((hash * totalWeight) >> 32)
  @fractional
  Scenario Outline: Fractional operator
    Given a String-flag with key "fractional-flag" and a default value "fallback"
    And a context containing a nested property with outer key "user" and inner key "name", with value "<name>"
    When the flag was evaluated with details
    Then the resolved details value should be "<value>"

    @fractional-v1
    Examples: v1
      | name  | value    |
      | jack  | spades   |
      | queen | clubs    |
      | ten   | diamonds |
      | nine  | hearts   |
      | 3     | diamonds |

    @fractional-v2
    Examples: v2
      | name  | value    |
      | jack  | hearts   |
      | queen | spades   |
      | ten   | clubs    |
      | nine  | diamonds |
      | 3     | clubs    |

  @fractional
  Scenario Outline: Fractional operator shorthand
    Given a String-flag with key "fractional-flag-shorthand" and a default value "fallback"
    And a context containing a targeting key with value "<targeting key>"
    When the flag was evaluated with details
    Then the resolved details value should be "<value>"

    @fractional-v1
    Examples: v1
      | targeting key    | value |
      | jon@company.com  | heads |
      | jane@company.com | tails |

    @fractional-v2
    Examples: v2
      | targeting key    | value |
      | jon@company.com  | heads |
      | jane@company.com | tails |

  @fractional
  Scenario Outline: Fractional operator with shared seed
    Given a String-flag with key "fractional-flag-A-shared-seed" and a default value "fallback"
    And a context containing a nested property with outer key "user" and inner key "name", with value "<name>"
    When the flag was evaluated with details
    Then the resolved details value should be "<value>"

    @fractional-v1
    Examples: v1
      | name  | value    |
      | jack  | hearts   |
      | queen | spades   |
      | ten   | hearts   |
      | nine  | diamonds |

    @fractional-v2
    Examples: v2
      | name  | value    |
      | seven | hearts   |
      | eight | diamonds |
      | nine  | clubs    |
      | two   | spades   |

  @fractional
  Scenario Outline: Second fractional operator with shared seed
    Given a String-flag with key "fractional-flag-B-shared-seed" and a default value "fallback"
    And a context containing a nested property with outer key "user" and inner key "name", with value "<name>"
    When the flag was evaluated with details
    Then the resolved details value should be "<value>"

    @fractional-v1
    Examples: v1
      | name  | value           |
      | jack  | ace-of-hearts   |
      | queen | ace-of-spades   |
      | ten   | ace-of-hearts   |
      | nine  | ace-of-diamonds |

    @fractional-v2
    Examples: v2
      | name  | value           |
      | seven | ace-of-hearts   |
      | eight | ace-of-diamonds |
      | nine  | ace-of-clubs    |
      | two   | ace-of-spades   |

  # Hash edge-case vectors — keys chosen by brute-force search so their
  # MurmurHash3-x86-32 (seed=0) falls at the six critical boundary values.
  # All keys are exact 6-char MurmurHash3-x86-32 (seed=0) preimages found by exhaustive search.
  # ejOoVL → hash=0          EXACT → bv(100)=0  → lower
  # bY9fO- → hash=1          EXACT → bv(100)=0  → lower
  # SI7p-  → hash=2147483647 EXACT i32::MAX     → bv(100)=49 → lower
  # 6LvT0  → hash=2147483648 EXACT i32::MIN u32 → bv(100)=50 → upper
  # ceQdGm → hash=4294967295 EXACT u32::MAX     → bv(100)=99 → upper
  @fractional @fractional-v2
  Scenario Outline: Fractional operator hash edge cases
    Given a String-flag with key "fractional-hash-edge-flag" and a default value "fallback"
    And a context containing a targeting key with value "<key>"
    When the flag was evaluated with details
    Then the resolved details value should be "<value>"
    Examples:
      | key    | value | note                                               |
      | ejOoVL | lower | hash=0 EXACT; absolute minimum; always first bucket |
      | bY9fO- | lower | hash=1 EXACT; one above zero; always first bucket  |
      | SI7p-  | lower | hash=i32::MAX EXACT; last before sign-bit boundary |
      | 6LvT0  | upper | hash=i32::MIN EXACT; first with sign-bit set       |
      | ceQdGm | upper | hash=u32::MAX EXACT; absolute maximum; always last |

  @string
  Scenario Outline: Substring operators
    Given a String-flag with key "starts-ends-flag" and a default value "fallback"
    And a context containing a key "id", with type "String" and with value "<id>"
    When the flag was evaluated with details
    Then the resolved details value should be "<value>"
    Examples:
      | id     | value   |
      | abcdef | prefix  |
      | uvwxyz | postfix |
      | abcxyz | prefix  |
      | lmnopq | none    |
      | 3      | none    |

  @semver
  Scenario Outline: Semantic version operator numeric comparison
    Given a String-flag with key "equal-greater-lesser-version-flag" and a default value "fallback"
    And a context containing a key "version", with type "String" and with value "<version>"
    When the flag was evaluated with details
    Then the resolved details value should be "<value>"
    Examples:
      | version     | value   |
      | 2.0.0       | equal   |
      | 2.1.0       | greater |
      | 1.9.0       | lesser  |
      | 2.0.0-alpha | lesser  |
      | 2.0.0.0     | none    |

  @semver
  Scenario Outline: Semantic version operator semantic comparison
    Given a String-flag with key "major-minor-version-flag" and a default value "fallback"
    And a context containing a key "version", with type "String" and with value "<version>"
    When the flag was evaluated with details
    Then the resolved details value should be "<value>"
    Examples:
      | version | value |
      | 3.0.1   | minor |
      | 3.1.0   | major |
      | 4.0.0   | none  |

  Scenario Outline: Time-based operations
    Given a Integer-flag with key "timestamp-flag" and a default value "0"
    And a context containing a key "time", with type "Integer" and with value "<time>"
    When the flag was evaluated with details
    Then the resolved details value should be "<value>"
    Examples:
      | time       | value |
      | 1          | -1    |
      | 4133980802 | 1     |

  Scenario Outline: Targeting by targeting key
    Given a String-flag with key "targeting-key-flag" and a default value "fallback"
    And a context containing a targeting key with value "<targeting key>"
    When the flag was evaluated with details
    Then the resolved details value should be "<value>"
    Then the reason should be "<reason>"
    Examples:
      | targeting key                        | value | reason          |
      | 5c3d8535-f81a-4478-a6d3-afaa4d51199e | hit   | TARGETING_MATCH |
      | f20bd32d-703b-48b6-bc8e-79d53c85134a | miss  | DEFAULT         |

  Scenario Outline: Errors and edge cases
    Given a Integer-flag with key "<key>" and a default value "3"
    When the flag was evaluated with details
    Then the resolved details value should be "<value>"
    And the error-code should be "<error_code>"
    Examples:
      | key                               | value | error_code  |
      | targeting-null-variant-flag       | 2     |             |
      | error-targeting-flag              | 3     | PARSE_ERROR |
      | missing-variant-targeting-flag    | 3     | GENERAL     |
      | non-string-variant-targeting-flag | 2     |             |
      | empty-targeting-flag              | 1     |             |
