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

  # /change bumps the flag set "version" and modifies metadata-change-modified-flag;
  # metadata-change-overriding-flag overrides "version" with its own value and is never modified;
  # metadata-change-inheriting-flag inherits "version", so its effective metadata changes
  @metadata-provider @metadata-change @rpc
  Scenario: Flag set metadata change reports the modified flag
    Given an option "selector" of type "String" with value "rawflags/selector-metadata-change-flags.json"
    And a metadata flagd provider
    And a String-flag with key "metadata-change-modified-flag" and a default value "foo"
    And a change event handler
    When the flag was modified
    And a change event was fired
    Then the flag should be part of the event payload

  @metadata-provider @metadata-change @rpc
  Scenario: Flag set metadata change doesn't report a flag that overrides the changed key
    Given an option "selector" of type "String" with value "rawflags/selector-metadata-change-flags.json"
    And a metadata flagd provider
    And a String-flag with key "metadata-change-overriding-flag" and a default value "foo"
    And a change event handler
    When the flag was modified
    And a change event was fired
    Then the flag should not be part of the event payload

  @metadata-provider @metadata-change @rpc
  Scenario: Flag set metadata change reports a flag that inherits the changed key
    Given an option "selector" of type "String" with value "rawflags/selector-metadata-change-flags.json"
    And a metadata flagd provider
    And a String-flag with key "metadata-change-inheriting-flag" and a default value "foo"
    And a change event handler
    When the flag was modified
    And a change event was fired
    Then the flag should be part of the event payload

  Scenario: Returns no metadata
    Given a Boolean-flag with key "boolean-flag" and a default value "true"
    And a stable flagd provider
    When the flag was evaluated with details
    Then the resolved metadata is empty
