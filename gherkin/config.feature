Feature: Configuration Test
"""markdown
  This is the official option configuration table
  | Option name           | Environment variable name      | Explanation                                                                     | Type & Values                | Default                       | Compatible resolver |
  | --------------------- | ------------------------------ | ------------------------------------------------------------------------------- | ---------------------------- | ----------------------------- | ------------------- |
  | resolver              | FLAGD_RESOLVER                 | mode of operation                                                               | String - `rpc`, `in-process` | rpc                           | rpc & in-process    |
  | host                  | FLAGD_HOST                     | remote host                                                                     | String                       | localhost                     | rpc & in-process    |
  | port                  | FLAGD_PORT                     | remote port                                                                     | int                          | 8013 (rpc), 8015 (in-process) | rpc & in-process    |
  | targetUri             | FLAGD_TARGET_URI               | alternative to host/port, supporting custom name resolution                     | string                       | null                          | rpc & in-process    |
  | tls                   | FLAGD_TLS                      | connection encryption                                                           | boolean                      | false                         | rpc & in-process    |
  | socketPath            | FLAGD_SOCKET_PATH              | alternative to host port, unix socket                                           | String                       | null                          | rpc & in-process    |
  | certPath              | FLAGD_SERVER_CERT_PATH         | tls cert path                                                                   | String                       | null                          | rpc & in-process    |
  | deadlineMs            | FLAGD_DEADLINE_MS              | deadline for unary calls, and timeout for initialization                        | int                          | 500                           | rpc & in-process    |
  | streamDeadlineMs      | FLAGD_STREAM_DEADLINE_MS       | deadline for streaming calls, useful as an application-layer keepalive          | int                          | 600000                        | rpc & in-process    |
  | retryBackoffMs        | FLAGD_RETRY_BACKOFF_MS         | initial backoff for stream retry                                                | int                          | 1000                          | rpc & in-process    |
  | retryBackoffMaxMs     | FLAGD_RETRY_BACKOFF_MAX_MS     | maximum backoff for stream retry                                                | int                          | 120000                        | rpc & in-process    |
  | retryGraceAttempts    | FLAGD_RETRY_GRACE_ATTEMPTS     | amount of stream retry attempts before provider moves from STALE to ERROR state | int                          | 5                             | rpc & in-process    |
  | keepAliveTime         | FLAGD_KEEP_ALIVE_TIME_MS       | http 2 keepalive                                                                | long                         | 0                             | rpc & in-process    |
  | cache                 | FLAGD_CACHE                    | enable cache of static flags                                                    | String - `lru`, `disabled`   | lru                           | rpc                 |
  | maxCacheSize          | FLAGD_MAX_CACHE_SIZE           | max size of static flag cache                                                   | int                          | 1000                          | rpc                 |
  | selector              | FLAGD_SOURCE_SELECTOR          | selects a single sync source to retrieve flags from only that source            | string                       | null                          | in-process          |
  | offlineFlagSourcePath | FLAGD_OFFLINE_FLAG_SOURCE_PATH | offline, file-based flag definitions, overrides host/port/targetUri             | string                       | null                          | in-process          |
  | offlinePollIntervalMs | FLAGD_OFFLINE_POLL_MS          | poll interval for reading offlineFlagSourcePath                                 | int                          | 5000                          | in-process          |
  | contextEnricher       | -                              | sync-metadata to evaluation context mapping function                            | function                     | identity function             | in-process          |
  """

  @rpc @in-process
  Scenario Outline: Default Config
    When a config was initialized
    Then the option "<option>" of type "<type>" should have the value "<default>"
    Examples: Basic
      | option     | type         | default   |
      | resolver   | ResolverType | rpc       |
      | host       | String       | localhost |
      | port       | Integer      | 8013      |
      | tls        | Boolean      | false     |
      | deadlineMs | Integer      | 500       |
    @targetURI
    Examples: Target URI
      | option    | type   | default |
      | targetUri | String | null    |
    @customCert
    Examples: Certificates
      | option   | type   | default |
      | certPath | String | null    |
    @unixsocket
    Examples: Unixsocket
      | option     | type   | default |
      | socketPath | String | null    |
    @events
    Examples: Events
      | option             | type    | default |
      | streamDeadlineMs   | Integer | 600000  |
      | keepAliveTime      | Long    | 0       |
      | retryBackoffMs     | Integer | 1000    |
      | retryBackoffMaxMs  | Integer | 120000  |
      | retryGraceAttempts | Integer | 5       |
    @sync
    Examples: Sync
      | option             | type    | default |
      | streamDeadlineMs   | Integer | 600000  |
      | keepAliveTime      | Long    | 0       |
      | retryBackoffMs     | Integer | 1000    |
      | retryBackoffMaxMs  | Integer | 120000  |
      | retryGraceAttempts | Integer | 5       |
      | selector           | String  | null    |
    @caching
    Examples: caching
      | option       | type      | default |
      | cache        | CacheType | lru     |
      | maxCacheSize | Integer   | 1000    |
    @offline
    Examples: offline
      | option                | type    | default |
      | offlineFlagSourcePath | String  | null    |
      | offlinePollIntervalMs | Integer | 5000    |

  @rpc
  Scenario Outline: Default Config RPC
    When a config was initialized for "rpc"
    Then the option "<option>" of type "<type>" should have the value "<default>"
    Examples:
      | option | type    | default |
      | port   | Integer | 8013    |

  @in-process
  Scenario Outline: Default Config In-Process
    When a config was initialized for "in-process"
    Then the option "<option>" of type "<type>" should have the value "<default>"
    Examples:
      | option | type    | default |
      | port   | Integer | 8015    |

  Scenario Outline: Dedicated Config
    Given an option "<option>" of type "<type>" with value "<value>"
    When a config was initialized
    Then the option "<option>" of type "<type>" should have the value "<value>"
    Examples:
      | option     | type         | value      |
      | resolver   | ResolverType | in-process |
      | host       | String       | local      |
      | tls        | Boolean      | True       |
      | port       | Integer      | 1234       |
      | deadlineMs | Integer      | 123        |
    @targetURI
    Examples: Target URI
      | option    | type   | value |
      | targetUri | String | path  |
    @customCert
    Examples:
      | option   | type   | value |
      | certPath | String | path  |
    @unixsocket
    Examples:
      | option     | type   | value |
      | socketPath | String | path  |
    @events
    Examples:
      | option             | type    | value  |
      | streamDeadlineMs   | Integer | 500000 |
      | keepAliveTime      | Long    | 5      |
      | retryBackoffMs     | Integer | 5000   |
      | retryBackoffMaxMs  | Integer | 12000  |
      | retryGraceAttempts | Integer | 10     |
    @sync
    Examples:
      | option             | type    | value    |
      | streamDeadlineMs   | Integer | 500000   |
      | keepAliveTime      | Long    | 5        |
      | retryBackoffMs     | Integer | 5000     |
      | retryBackoffMaxMs  | Integer | 12000    |
      | retryGraceAttempts | Integer | 10       |
      | selector           | String  | selector |
    @caching
    Examples:
      | option       | type      | value    |
      | cache        | CacheType | disabled |
      | maxCacheSize | Integer   | 1236     |
    @offline
    Examples:
      | option                | type    | value |
      | offlineFlagSourcePath | String  | path  |
      | offlinePollIntervalMs | Integer | 1000  |

  Scenario Outline: Dedicated Config via Env_var
    Given an environment variable "<env>" with value "<value>"
    When a config was initialized
    Then the option "<option>" of type "<type>" should have the value "<value>"
    Examples:
      | option     | env               | type         | value      |
      | resolver   | FLAGD_RESOLVER    | ResolverType | in-process |
      | resolver   | FLAGD_RESOLVER    | ResolverType | IN-PROCESS |
      | resolver   | FLAGD_RESOLVER    | ResolverType | rpc        |
      | resolver   | FLAGD_RESOLVER    | ResolverType | RPC        |
      | host       | FLAGD_HOST        | String       | local      |
      | tls        | FLAGD_TLS         | Boolean      | True       |
      | port       | FLAGD_PORT        | Integer      | 1234       |
      | deadlineMs | FLAGD_DEADLINE_MS | Integer      | 123        |
    @targetURI
    Examples: Target URI
      | option    | env              | type   | value |
      | targetUri | FLAGD_TARGET_URI | String | path  |
    @customCert
    Examples:
      | option   | env                    | type   | value |
      | certPath | FLAGD_SERVER_CERT_PATH | String | path  |
    @unixsocket
    Examples:
      | option     | env               | type   | value |
      | socketPath | FLAGD_SOCKET_PATH | String | path  |
    @events
    Examples:
      | option             | env                        | type    | value  |
      | streamDeadlineMs   | FLAGD_STREAM_DEADLINE_MS   | Integer | 500000 |
      | keepAliveTime      | FLAGD_KEEP_ALIVE_TIME_MS   | Long    | 5      |
      | retryBackoffMs     | FLAGD_RETRY_BACKOFF_MS     | Integer | 5000   |
      | retryBackoffMaxMs  | FLAGD_RETRY_BACKOFF_MAX_MS | Integer | 12000  |
      | retryGraceAttempts | FLAGD_RETRY_GRACE_ATTEMPTS | Integer | 10     |
    @sync
    Examples:
      | option             | env                        | type    | value    |
      | streamDeadlineMs   | FLAGD_STREAM_DEADLINE_MS   | Integer | 500000   |
      | keepAliveTime      | FLAGD_KEEP_ALIVE_TIME_MS   | Long    | 5        |
      | retryBackoffMs     | FLAGD_RETRY_BACKOFF_MS     | Integer | 5000     |
      | retryBackoffMaxMs  | FLAGD_RETRY_BACKOFF_MAX_MS | Integer | 12000    |
      | retryGraceAttempts | FLAGD_RETRY_GRACE_ATTEMPTS | Integer | 10       |
      | selector           | FLAGD_SOURCE_SELECTOR      | String  | selector |
    @caching
    Examples:
      | option       | env                  | type      | value    |
      | cache        | FLAGD_CACHE          | CacheType | disabled |
      | maxCacheSize | FLAGD_MAX_CACHE_SIZE | Integer   | 1236     |
    @offline
    Examples:
      | option                | env                            | type    | value |
      | offlineFlagSourcePath | FLAGD_OFFLINE_FLAG_SOURCE_PATH | String  | path  |
      | offlinePollIntervalMs | FLAGD_OFFLINE_POLL_MS          | Integer | 1000  |

  Scenario Outline: Dedicated Config via Env_var and set
    Given an environment variable "<env>" with value "<env-value>"
    And an option "<option>" of type "<type>" with value "<value>"
    When a config was initialized
    Then the option "<option>" of type "<type>" should have the value "<value>"
    Examples:
      | option     | env               | type         | value      | env-value |
      | resolver   | FLAGD_RESOLVER    | ResolverType | in-process | rpc       |
      | host       | FLAGD_HOST        | String       | local      | l         |
      | tls        | FLAGD_TLS         | Boolean      | True       | False     |
      | port       | FLAGD_PORT        | Integer      | 1234       | 3456      |
      | deadlineMs | FLAGD_DEADLINE_MS | Integer      | 123        | 345       |
    @targetURI
    Examples: Target URI
      | option    | env              | type   | value | env-value |
      | targetUri | FLAGD_TARGET_URI | String | path  | fun       |
    @customCert
    Examples:
      | option   | env                    | type   | value | env-value |
      | certPath | FLAGD_SERVER_CERT_PATH | String | path  | rpc       |
    @unixsocket
    Examples:
      | option     | env               | type   | value | env-value |
      | socketPath | FLAGD_SOCKET_PATH | String | path  | rpc       |
    @events
    Examples:
      | option             | env                        | type    | value  | env-value |
      | streamDeadlineMs   | FLAGD_STREAM_DEADLINE_MS   | Integer | 500000 | 400       |
      | keepAliveTime      | FLAGD_KEEP_ALIVE_TIME_MS   | Long    | 5      | 4         |
      | retryBackoffMs     | FLAGD_RETRY_BACKOFF_MS     | Integer | 5000   | 4         |
      | retryBackoffMaxMs  | FLAGD_RETRY_BACKOFF_MAX_MS | Integer | 12000  | 4         |
      | retryGraceAttempts | FLAGD_RETRY_GRACE_ATTEMPTS | Integer | 10     | 4         |
    @sync
    Examples:
      | option             | env                        | type    | value    | env-value |
      | streamDeadlineMs   | FLAGD_STREAM_DEADLINE_MS   | Integer | 500000   | 400       |
      | keepAliveTime      | FLAGD_KEEP_ALIVE_TIME_MS   | Long    | 5        | 4         |
      | retryBackoffMs     | FLAGD_RETRY_BACKOFF_MS     | Integer | 5000     | 4         |
      | retryBackoffMaxMs  | FLAGD_RETRY_BACKOFF_MAX_MS | Integer | 12000    | 4         |
      | retryGraceAttempts | FLAGD_RETRY_GRACE_ATTEMPTS | Integer | 10       | 4         |
      | selector           | FLAGD_SOURCE_SELECTOR      | String  | selector | sele      |
    @caching
    Examples:
      | option       | env                  | type      | value    | env-value |
      | cache        | FLAGD_CACHE          | CacheType | disabled | lru       |
      | maxCacheSize | FLAGD_MAX_CACHE_SIZE | Integer   | 1236     | 2345      |
    @offline
    Examples:
      | option                | env                            | type    | value | env-value |
      | offlineFlagSourcePath | FLAGD_OFFLINE_FLAG_SOURCE_PATH | String  | path  | lll       |
      | offlinePollIntervalMs | FLAGD_OFFLINE_POLL_MS          | Integer | 1000  | 4         |
