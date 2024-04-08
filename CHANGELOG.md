# Changelog

## [0.5.3](https://github.com/open-feature/flagd-testbed/compare/v0.5.2...v0.5.3) (2024-04-08)


### Features

* test multiple fractional flags with shared seed ([#115](https://github.com/open-feature/flagd-testbed/issues/115)) ([25544e4](https://github.com/open-feature/flagd-testbed/commit/25544e43d65500ea085d6f0e242b9a616a51f776))


### Bug Fixes

* **deps:** update golang.org/x/exp digest to a685a6e ([#113](https://github.com/open-feature/flagd-testbed/issues/113)) ([620df72](https://github.com/open-feature/flagd-testbed/commit/620df72fe2982004ffe9c3e9798de95e92178084))

## [0.5.2](https://github.com/open-feature/flagd-testbed/compare/v0.5.1...v0.5.2) (2024-02-22)


### Bug Fixes

* **deps:** update golang.org/x/exp digest to ec58324 ([#100](https://github.com/open-feature/flagd-testbed/issues/100)) ([210c78b](https://github.com/open-feature/flagd-testbed/commit/210c78b292e2ff4ad805ea953f956c31a5c5751a))
* **deps:** update module google.golang.org/grpc to v1.61.1 ([#106](https://github.com/open-feature/flagd-testbed/issues/106)) ([8201fdc](https://github.com/open-feature/flagd-testbed/commit/8201fdc5afe261174c9abf141b1ad4efa9492c94))
* update server.go to use new metadata struct ([#112](https://github.com/open-feature/flagd-testbed/issues/112)) ([6780f99](https://github.com/open-feature/flagd-testbed/commit/6780f9960832be94674b4b62edd85057640b4fbe))

## [0.5.1](https://github.com/open-feature/flagd-testbed/compare/v0.5.0...v0.5.1) (2024-02-13)


### Features

* provider unavailable, targeting key tests ([#103](https://github.com/open-feature/flagd-testbed/issues/103)) ([db43977](https://github.com/open-feature/flagd-testbed/commit/db439774595a8f430cda82c452eaf31ff9fb836b))

## [0.5.0](https://github.com/open-feature/flagd-testbed/compare/v0.4.11...v0.5.0) (2024-02-06)


### ⚠ BREAKING CHANGES

* add new sync proto, rm old sync proto ([#99](https://github.com/open-feature/flagd-testbed/issues/99))

### Features

* add new sync proto, rm old sync proto ([#99](https://github.com/open-feature/flagd-testbed/issues/99)) ([fed2389](https://github.com/open-feature/flagd-testbed/commit/fed23894bebae378f5fc7c01f1b86ef8dbf1b05e))

## [0.4.11](https://github.com/open-feature/flagd-testbed/compare/v0.4.10...v0.4.11) (2024-01-26)


### Features

* Improve sync service  ([#97](https://github.com/open-feature/flagd-testbed/issues/97)) ([99bd668](https://github.com/open-feature/flagd-testbed/commit/99bd668c58403d2676218ca669b38bf7f98f46fb))

## [0.4.10](https://github.com/open-feature/flagd-testbed/compare/v0.4.9...v0.4.10) (2023-12-22)


### Bug Fixes

* **deps:** update golang.org/x/exp digest to dc181d7 ([#56](https://github.com/open-feature/flagd-testbed/issues/56)) ([bd04499](https://github.com/open-feature/flagd-testbed/commit/bd044994e61eef54b91dd0e6d6b67107aa2b233e))
* **deps:** update module github.com/fsnotify/fsnotify to v1.7.0 ([#75](https://github.com/open-feature/flagd-testbed/issues/75)) ([d59613e](https://github.com/open-feature/flagd-testbed/commit/d59613e19543a991a6b504463be06d85036a575b))
* **deps:** update module google.golang.org/grpc to v1.60.1 ([#57](https://github.com/open-feature/flagd-testbed/issues/57)) ([aef5f27](https://github.com/open-feature/flagd-testbed/commit/aef5f273bc759a5c4c087dda0490a52bbc4ddb4b))

## [0.4.9](https://github.com/open-feature/flagd-testbed/compare/v0.4.8...v0.4.9) (2023-12-15)


### Features

* add empty context test ([#88](https://github.com/open-feature/flagd-testbed/issues/88)) ([ca1d46c](https://github.com/open-feature/flagd-testbed/commit/ca1d46c9f569408d670a5ce4d349a13df5656b46))

## [0.4.8](https://github.com/open-feature/flagd-testbed/compare/v0.4.7...v0.4.8) (2023-12-05)


### Features

* add tests for config edge cases ([#85](https://github.com/open-feature/flagd-testbed/issues/85)) ([14eadc1](https://github.com/open-feature/flagd-testbed/commit/14eadc106a1ecdc2f381a5eee83b4f111cca3f3c))

## [0.4.7](https://github.com/open-feature/flagd-testbed/compare/v0.4.6...v0.4.7) (2023-11-27)


### Bug Fixes

* update flagd ([e65517f](https://github.com/open-feature/flagd-testbed/commit/e65517f247bb7d60f8036f6019c1b577560168ff))

## [0.4.6](https://github.com/open-feature/flagd-testbed/compare/v0.4.5...v0.4.6) (2023-11-20)


### Bug Fixes

* race condition if pid too long to kill ([#80](https://github.com/open-feature/flagd-testbed/issues/80)) ([4375630](https://github.com/open-feature/flagd-testbed/commit/4375630a08e62a0e68f77fce2ba162e288e6354b))

## [0.4.5](https://github.com/open-feature/flagd-testbed/compare/v0.4.4...v0.4.5) (2023-11-20)


### Features

* add unstable testbeds ([#77](https://github.com/open-feature/flagd-testbed/issues/77)) ([821c5de](https://github.com/open-feature/flagd-testbed/commit/821c5deb0938ed5bef53e046349a5806d53ee4a0))

## [0.4.4](https://github.com/open-feature/flagd-testbed/compare/v0.4.3...v0.4.4) (2023-09-29)


### Bug Fixes

* zero value gherkin ([12a6651](https://github.com/open-feature/flagd-testbed/commit/12a665196fdaf3d010ddca0f56da1b410cf0e840))

## [0.4.3](https://github.com/open-feature/flagd-testbed/compare/v0.4.2...v0.4.3) (2023-09-21)


### Bug Fixes

* remove otel, handle stream close ([#70](https://github.com/open-feature/flagd-testbed/issues/70)) ([30473e6](https://github.com/open-feature/flagd-testbed/commit/30473e6aba34d02162e803bea451efa1a360e95a))

## [0.4.2](https://github.com/open-feature/flagd-testbed/compare/v0.4.1...v0.4.2) (2023-09-19)


### Features

* add evaluator support in sync ([#68](https://github.com/open-feature/flagd-testbed/issues/68)) ([9c6fed0](https://github.com/open-feature/flagd-testbed/commit/9c6fed06cc5bd7803ae69ec0f0bfb6fc9c0b18e4))

## [0.4.1](https://github.com/open-feature/flagd-testbed/compare/v0.4.0...v0.4.1) (2023-09-18)


### Bug Fixes

* update to flagd 0.6.6 ([7e92313](https://github.com/open-feature/flagd-testbed/commit/7e92313ff3255a0248ab23e8b1b47d9d5c5e0915))

## [0.4.0](https://github.com/open-feature/flagd-testbed/compare/v0.3.2...v0.4.0) (2023-09-14)


### ⚠ BREAKING CHANGES

* update fractional test data for 32bit murmur3 ([#65](https://github.com/open-feature/flagd-testbed/issues/65))

### Bug Fixes

* update fractional test data for 32bit murmur3 ([#65](https://github.com/open-feature/flagd-testbed/issues/65)) ([bbba763](https://github.com/open-feature/flagd-testbed/commit/bbba7635f5921e98474ff6a3551ed20ca5d02d8c))

## [0.3.2](https://github.com/open-feature/flagd-testbed/compare/v0.3.1...v0.3.2) (2023-09-08)


### Bug Fixes

* various gherkin fixes ([#59](https://github.com/open-feature/flagd-testbed/issues/59)) ([4b1ed83](https://github.com/open-feature/flagd-testbed/commit/4b1ed83d6251a6feae5cb10d7cd5e1f5b96c00d3))

## [0.3.1](https://github.com/open-feature/flagd-testbed/compare/v0.3.0...v0.3.1) (2023-09-07)


### Features

* flagd gherkin suite and flags ([#54](https://github.com/open-feature/flagd-testbed/issues/54)) ([81cb78b](https://github.com/open-feature/flagd-testbed/commit/81cb78ba051da86add66ca385fa7c540f340e117))

## [0.3.0](https://github.com/open-feature/test-harness/compare/v0.2.6...v0.3.0) (2023-09-01)


### ⚠ BREAKING CHANGES

* remove gherkin, add events support ([#51](https://github.com/open-feature/test-harness/issues/51))

### Features

* dummy sync server ([#53](https://github.com/open-feature/test-harness/issues/53)) ([649c770](https://github.com/open-feature/test-harness/commit/649c77050b80bb1fd414a51077a1cbc423d1cfe3))
* remove gherkin, add events support ([#51](https://github.com/open-feature/test-harness/issues/51)) ([335f89e](https://github.com/open-feature/test-harness/commit/335f89e6181303a7d26fdbf9c366aea850348abf))

## [0.2.6](https://github.com/open-feature/test-harness/compare/v0.2.5...v0.2.6) (2023-02-24)


### Features

* increase sleep in caching tests from 250ms to 1000ms ([#44](https://github.com/open-feature/test-harness/issues/44)) ([a07c1d0](https://github.com/open-feature/test-harness/commit/a07c1d0496d3c53edad50748f0b6d421d51598a9))

## [0.2.5](https://github.com/open-feature/test-harness/compare/v0.2.4...v0.2.5) (2023-02-24)


### Features

* increase sleep in caching tests from 100ms to 250ms ([#42](https://github.com/open-feature/test-harness/issues/42)) ([455b612](https://github.com/open-feature/test-harness/commit/455b6126692d1264726797e3b7e727d7302b90d0))

## [0.2.4](https://github.com/open-feature/test-harness/compare/v0.2.3...v0.2.4) (2023-02-24)


### Features

* increase sleep in caching tests from 50ms to 100ms ([#40](https://github.com/open-feature/test-harness/issues/40)) ([5baf0cc](https://github.com/open-feature/test-harness/commit/5baf0cc4b768652da77431cb38def588ba70a0fd))

## [0.2.3](https://github.com/open-feature/test-harness/compare/v0.2.2...v0.2.3) (2023-02-24)


### Features

* semanticCommitType set to feat to create releases from flagd upgrades ([#37](https://github.com/open-feature/test-harness/issues/37)) ([84f821c](https://github.com/open-feature/test-harness/commit/84f821ca5f575d3c501a40b4efbf0918b3d34196))
* symlink to testing-flags.json ([#39](https://github.com/open-feature/test-harness/issues/39)) ([147487e](https://github.com/open-feature/test-harness/commit/147487e69d19ef8098942d14ddbf860a2587d366))

## [0.2.2](https://github.com/open-feature/test-harness/compare/v0.2.1...v0.2.2) (2023-01-26)


### Bug Fixes

* change second Given to And ([#28](https://github.com/open-feature/test-harness/issues/28)) ([13d5bd5](https://github.com/open-feature/test-harness/commit/13d5bd50a542c7cc1c297d022438af4c47e19b58))

## [0.2.1](https://github.com/open-feature/test-harness/compare/v0.2.0...v0.2.1) (2023-01-12)


### Bug Fixes

* properly set the version used for the image tag ([#26](https://github.com/open-feature/test-harness/issues/26)) ([8f983aa](https://github.com/open-feature/test-harness/commit/8f983aaf5d8267fcd3c0746ad826a1a85586ad79))

## [0.2.0](https://github.com/open-feature/test-harness/compare/v0.1.0...v0.2.0) (2023-01-12)


### ⚠ BREAKING CHANGES

* amend caching scenarios to check that cache is not just being purged ([#20](https://github.com/open-feature/test-harness/issues/20))

### Features

* amend caching scenarios to check that cache is not just being purged ([#20](https://github.com/open-feature/test-harness/issues/20)) ([8683403](https://github.com/open-feature/test-harness/commit/8683403ed2349ed2ee52796e8e0b156cb7b24f31))
