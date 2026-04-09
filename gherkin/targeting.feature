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

  @fractional @fractional-v2
  Scenario: Fractional operator with single entry always resolves to the only variant
    Given a String-flag with key "fractional-single-entry-flag" and a default value "fallback"
    When the flag was evaluated with details
    Then the resolved details value should be "single"

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
      | key    | value |
      | ejOoVL | lower |
      | bY9fO- | lower |
      | SI7p-  | lower |
      | 6LvT0  | upper |
      | ceQdGm | upper |

  # Nested JSON Logic expressions as bucket variant names.
  # Requires providers to support the @fractional-nested feature.
  # Use -t "not @fractional-nested" to exclude during transition.
  @fractional @fractional-nested
  Scenario Outline: Fractional operator with nested if expression as variant name
    # fractional-nested-if-flag: seed=targetingKey, bucket0=[if(tier=="premium","premium","standard"),50], bucket1=["standard",50]
    # jon@company.com bv(100)=36 → bucket0; user1 bv(100)=76 → bucket1
    Given a String-flag with key "fractional-nested-if-flag" and a default value "fallback"
    And a context containing a targeting key with value "<targetingKey>"
    And a context containing a key "tier", with type "String" and with value "<tier>"
    When the flag was evaluated with details
    Then the resolved details value should be "<value>"
    Examples:
      | targetingKey    | tier    | value    |
      | jon@company.com | premium | premium  |
      | jon@company.com | basic   | standard |
      | user1           | premium | standard |
      | user1           | basic   | standard |

  @fractional @fractional-nested
  Scenario Outline: Fractional operator with nested var expression as variant name
    # fractional-nested-var-flag: seed=targetingKey, bucket0=[var("color"),50], bucket1=["blue",50]
    # jon@company.com bv(100)=36 → bucket0 (resolves var "color"); user1 bv(100)=76 → bucket1 ("blue")
    Given a String-flag with key "fractional-nested-var-flag" and a default value "fallback"
    And a context containing a targeting key with value "<targetingKey>"
    And a context containing a key "color", with type "String" and with value "<color>"
    When the flag was evaluated with details
    Then the resolved details value should be "<value>"
    Examples:
      | targetingKey    | color  | value    |
      | jon@company.com | red    | red      |
      | jon@company.com | green  | green    |
      | user1           | red    | blue     |
      | jon@company.com | yellow | fallback |
      | jon@company.com |        | fallback |

  @fractional @fractional-nested
  Scenario Outline: Fractional operator with nested if expression as weight
    # fractional-nested-weight-flag: seed=targetingKey, bucket0=["red",if(tier=="premium",100,0)], bucket1=["blue",10]
    Given a String-flag with key "fractional-nested-weight-flag" and a default value "fallback"
    And a context containing a targeting key with value "<targetingKey>"
    And a context containing a key "tier", with type "String" and with value "<tier>"
    When the flag was evaluated with details
    Then the resolved details value should be "<value>"
    Examples:
      | targetingKey    | tier    | value   |
      | jon@company.com | premium | red     |
      | jon@company.com | basic   | blue    |
      | user1           | premium | red     |
      | user1           | basic   | blue    |

  @fractional @fractional-nested
  Scenario: Fractional as condition
    Given a String-flag with key "fractional-as-condition-flag" and a default value "zero"
    And a context containing a targeting key with value "some-targeting-key"
    When the flag was evaluated with details
    Then the resolved details value should be "hundreds"

  @fractional @fractional-nested
  Scenario: Fractional as condition evaluates false path
    Given a String-flag with key "fractional-as-condition-false-flag" and a default value "zero"
    And a context containing a targeting key with value "some-targeting-key"
    When the flag was evaluated with details
    Then the resolved details value should be "ones"

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

  @semver @semver-edge-cases @semver-v-prefix
  Scenario Outline: sem_ver v-prefix handling
    Given a String-flag with key "semver-v-prefix-flag" and a default value "fallback"
    And a context containing a key "version", with type "String" and with value "<version>"
    When the flag was evaluated with details
    Then the resolved details value should be "<value>"
    Examples:
      | version | value    |
      | 1.0.0   | match    |
      | v1.0.0  | match    |
      | V1.0.0  | match    |
      | 2.0.0   | no-match |

  @semver @semver-edge-cases @semver-partial-version
  Scenario Outline: sem_ver partial version handling
    Given a String-flag with key "semver-partial-version-flag" and a default value "fallback"
    And a context containing a key "version", with type "<type>" and with value "<version>"
    When the flag was evaluated with details
    Then the resolved details value should be "<value>"
    Examples:
      | version | type    | value    |
      | 1.5.0   | String  | match    |
      | 1.0.0   | String  | match    |
      | 1.0     | String  | match    |
      | 1       | String  | match    |
      | 1       | Integer | match    |
      | 2.0.0   | String  | no-match |

  @semver @semver-edge-cases @semver-build-metadata
  Scenario Outline: sem_ver build metadata ignored
    Given a String-flag with key "semver-build-metadata-flag" and a default value "fallback"
    And a context containing a key "version", with type "String" and with value "<version>"
    When the flag was evaluated with details
    Then the resolved details value should be "<value>"
    Examples:
      | version       | value    |
      | 1.0.0         | match    |
      | 1.0.0+other   | match    |
      | 2.0.0         | no-match |

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

  @operator-errors
  Scenario Outline: Custom operator errors return null and fall back to default variant
    Given a String-flag with key "<key>" and a default value "wrong"
    And a context containing a key "version", with type "String" and with value "<context_value>"
    When the flag was evaluated with details
    Then the resolved details value should be "fallback"
    And the reason should be "DEFAULT"
    Examples:
      | key                          | context_value   |
      | semver-invalid-version-flag  | not-a-version   |
      | semver-invalid-operator-flag | 1.0.0           |

  @operator-errors
  Scenario: fractional operator with missing bucket key falls back to default variant
    Given a String-flag with key "fractional-null-bucket-key-flag" and a default value "wrong"
    When the flag was evaluated with details
    Then the resolved details value should be "fallback"
    And the reason should be "DEFAULT"

  # Follow-up error scenarios from https://github.com/open-feature/flagd/issues/1874
  # Operators must return null (not false) on error so the default variant is selected.

  @operator-errors @string
  Scenario Outline: starts_with and ends_with return null for non-string input
    Given a String-flag with key "<key>" and a default value "wrong"
    And a context containing a key "num", with type "Integer" and with value "123"
    When the flag was evaluated with details
    Then the resolved details value should be "fallback"
    And the reason should be "DEFAULT"
    Examples:
      | key                         |
      | starts-with-non-string-flag |
      | ends-with-non-string-flag   |

  @operator-errors @string
  Scenario Outline: starts_with and ends_with return null for wrong argument count
    Given a String-flag with key "<key>" and a default value "wrong"
    When the flag was evaluated with details
    Then the resolved details value should be "fallback"
    And the reason should be "DEFAULT"
    Examples:
      | key                         |
      | starts-with-wrong-args-flag |
      | ends-with-wrong-args-flag   |

  @operator-errors @semver
  Scenario: sem_ver returns null for wrong argument count
    Given a String-flag with key "semver-wrong-args-flag" and a default value "wrong"
    And a context containing a key "version", with type "String" and with value "1.0.0"
    When the flag was evaluated with details
    Then the resolved details value should be "fallback"
    And the reason should be "DEFAULT"

  @operator-errors @fractional
  Scenario: fractional with all-zero bucket weights falls back to default variant
    Given a String-flag with key "fractional-zero-weights-flag" and a default value "wrong"
    And a context containing a targeting key with value "any-user"
    When the flag was evaluated with details
    Then the resolved details value should be "fallback"
    And the reason should be "DEFAULT"

  @operator-errors @fractional
  Scenario: fractional negative bucket weight is clamped to zero
    # ["one", -50] is treated as ["one", 0]; "two" gets 100% of the weight
    Given a String-flag with key "fractional-negative-weight-flag" and a default value "wrong"
    And a context containing a targeting key with value "any-user"
    When the flag was evaluated with details
    Then the resolved details value should be "two"
