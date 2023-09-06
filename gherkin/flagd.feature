Feature: flagd providers

  # This test suite contains scenarios to test flagd providers.
  # It's associated with the flags configured in flags/changing-flag.json and flags/zero-flags.json.
  # It should be used in conjunection with the suites supplied by the OpenFeature specification.

  Background:
    Given a flagd provider is set

  # events
  Scenario: Provider ready event
    When a PROVIDER_READY handler is added
    Then the PROVIDER_READY handler must run

  Scenario: Flag change event
    When a PROVIDER_CONFIGURATION_CHANGED handler is added
    And a flag with key "changing-flag" is modified
    Then the PROVIDER_CONFIGURATION_CHANGED handler must run
    And the event details must indicate "changing-flag" was altered

  # zero evaluation
  Scenario: Resolves boolean zero value
    When a boolean flag with key "boolean-zero-flag" is evaluated with default value "true"
    Then the resolved boolean value should be "false"

  Scenario: Resolves string zero value
    When a string flag with key "string-zero-flag" is evaluated with default value "hi"
    Then the resolved string value should be ""

  Scenario: Resolves integer zero value
    When an integer flag with key "integer-zero-flag" is evaluated with default value 1
    Then the resolved integer value should be 0

  Scenario: Resolves float zero value
    When a float flag with key "float-zero-flag" is evaluated with default value 0.1
    Then the resolved float value should be 0.0
    