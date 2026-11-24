@in-process @metadata @file
Feature: flag and flag set metadata

  # This test suite contains scenarios to test flagd providers.
  # It's associated with the flags configured in flags.
  # It should be used in conjunction with the suites supplied by the OpenFeature specification.

  Scenario: Returns metadata
    Given a stable flagd provider
    And a Boolean-flag with key "metadata-flag" and a default value "true"
    When the flag was evaluated with details
    Then the resolved metadata should contain
      | key     | metadata_type | value |
      | string  | String        | a     |
      | integer | Integer       | 1     |
      | float   | Float         | 1.2   |
      | boolean | Boolean       | true  |

  @metadata-provider
  Scenario: Returns flag set metadata
    Given an option "selector" of type "String" with value "rawflags/selector-flag-combined-metadata.json"
    And a metadata flagd provider
    And a Boolean-flag with key "only-set-metadata-flag" and a default value "true"
    When the flag was evaluated with details
    Then the resolved metadata should contain
      | key              | metadata_type | value |
      | string           | String        | b     |
      | integer          | Integer       | 2     |
      | float            | Float         | 2.2   |
      | boolean          | Boolean       | false |
      | flag-set-string  | String        | c     |
      | flag-set-integer | Integer       | 3     |
      | flag-set-float   | Float         | 3.2   |
      | flag-set-boolean | Boolean       | false |

  @metadata-provider
  Scenario: Flag metadata overwrites flag set metadata
    Given an option "selector" of type "String" with value "rawflags/selector-flag-combined-metadata.json"
    And a metadata flagd provider
    And a Boolean-flag with key "combined-metadata-flag" and a default value "true"
    When the flag was evaluated with details
    Then the resolved metadata should contain
      | key              | metadata_type | value |
      | string           | String        | a     |
      | integer          | Integer       | 1     |
      | float            | Float         | 1.2   |
      | boolean          | Boolean       | true  |
      | flag-set-string  | String        | c     |
      | flag-set-integer | Integer       | 3     |
      | flag-set-float   | Float         | 3.2   |
      | flag-set-boolean | Boolean       | false |

  Scenario: Returns no metadata
    Given a Boolean-flag with key "boolean-flag" and a default value "true"
    And a stable flagd provider
    When the flag was evaluated with details
    Then the resolved metadata is empty

  # resolve rule metadata over flag set metadata; a selector file keeps that flag set metadata off other flags.
  # The other resolve scenarios are in targeting.feature.
  @resolve @metadata-provider
  Scenario: Rule metadata overwrites flag metadata, which overwrites flag set metadata
    Given an option "selector" of type "String" with value "rawflags/selector-resolve-metadata.json"
    And a metadata flagd provider
    And a String-flag with key "resolve-metadata-precedence-flag" and a default value "fallback"
    When the flag was evaluated with details
    Then the resolved details value should be "on"
    And the reason should be "ALLOWLIST"
    And the resolved metadata should contain
      | key     | metadata_type | value    |
      | details | String        | rule     |
      | owner   | String        | flag     |
      | team    | String        | flag set |

  # flagSetId and version are reserved for flag set metadata; the computed keys are skipped, the other pairs still apply
  @resolve @metadata-provider
  Scenario: Resolve metadata can't override reserved flag set metadata keys
    Given an option "selector" of type "String" with value "rawflags/selector-resolve-metadata.json"
    And a metadata flagd provider
    And a String-flag with key "resolve-reserved-metadata-flag" and a default value "fallback"
    When the flag was evaluated with details
    Then the resolved details value should be "on"
    And the reason should be "TARGETING_MATCH"
    And the resolved metadata should contain
      | key       | metadata_type | value       |
      | flagSetId | String        | resolve-set |
      | version   | String        | 1           |
      | details   | String        | rule        |
