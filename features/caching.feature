Feature: Flag caching

# This test suite contains scenarios relating to caching, particularly when an SDK is configured to use a flagd provider. Not all providers may observe these caching semantics.

  Background:
    Given an openfeature client is registered with cache enabled

  # caches value
  Scenario: Caches boolean value
    Given a boolean flag with key "boolean-flag" is evaluated with details and default value "false"
    When a boolean flag with key "boolean-flag" is evaluated with details and default value "false"
    Then the resolved boolean details reason should be "CACHED"

  Scenario: Caches string value
    Given a string flag with key "string-flag" is evaluated with details and default value "bye"
    When a string flag with key "string-flag" is evaluated with details and default value "bye"
    Then the resolved string details reason should be "CACHED"

  Scenario: Caches integer value
    Given an integer flag with key "integer-flag" is evaluated with details and default value 1
    When an integer flag with key "integer-flag" is evaluated with details and default value 1
    Then the resolved integer details reason should be "CACHED"

  Scenario: Caches float value
    Given a float flag with key "float-flag" is evaluated with details and default value 0.1
    When a float flag with key "float-flag" is evaluated with details and default value 0.1
    Then the resolved float details reason should be "CACHED"

  Scenario: Caches object value
    Given an object flag with key "object-flag" is evaluated with details and a null default value
    When an object flag with key "object-flag" is evaluated with details and a null default value
    Then the resolved object details reason should be "CACHED"

  # invalidates cached value
  Scenario: Invalidates cache on boolean flag configuration update
    Given a boolean flag with key "boolean-flag" is evaluated with details and default value "false"
    When the flag's configuration with key "boolean-flag" is updated to defaultVariant "off"
    And sleep for 50 milliseconds
    And a boolean flag with key "boolean-flag" is evaluated with details and default value "false"
    Then the resolved boolean details reason should be "STATIC"

  Scenario: Invalidates cache on string flag configuration update
    Given a string flag with key "string-flag" is evaluated with details and default value "bye"
    When the flag's configuration with key "string-flag" is updated to defaultVariant "parting"
    And sleep for 50 milliseconds
    And a string flag with key "string-flag" is evaluated with details and default value "bye"
    Then the resolved string details reason should be "STATIC"

  Scenario: Invalidates cache on integer flag configuration update
    Given an integer flag with key "integer-flag" is evaluated with details and default value 1
    When the flag's configuration with key "integer-flag" is updated to defaultVariant "one"
    And sleep for 50 milliseconds
    And an integer flag with key "integer-flag" is evaluated with details and default value 1
    Then the resolved integer details reason should be "STATIC"

  Scenario: Invalidates cache on float flag configuration update
    Given a float flag with key "float-flag" is evaluated with details and default value 0.1
    When the flag's configuration with key "float-flag" is updated to defaultVariant "tenth"
    And sleep for 50 milliseconds
    And a float flag with key "float-flag" is evaluated with details and default value 0.1
    Then the resolved float details reason should be "STATIC"

  Scenario: Invalidates cache on object flag configuration update
    Given an object flag with key "object-flag" is evaluated with details and a null default value
    When the flag's configuration with key "object-flag" is updated to defaultVariant "empty"
    And sleep for 50 milliseconds
    And an object flag with key "object-flag" is evaluated with details and a null default value
    Then the resolved object details reason should be "STATIC"

  Scenario: Non-static flag not cached
    Given a string flag with key "context-aware" is evaluated with details and default value "EXTERNAL"
    When a string flag with key "context-aware" is evaluated with details and default value "EXTERNAL"
    Then the resolved string details reason should be "TARGETING_MATCH"
