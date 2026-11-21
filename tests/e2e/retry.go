// Copyright 2026 Han Li and contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package e2e

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"testing"
	"time"
)

// retryEnv names the environment variable that sets the attempt budget of
// network-touching calls.
const retryEnv = "E2E_RETRY_ATTEMPTS"

// defaultRetryAttempts is the attempt budget when retryEnv is unset.
const defaultRetryAttempts = 3

// retryStep is the unit of the linear backoff: after the n-th failed attempt
// the harness waits n times retryStep.
const retryStep = 10 * time.Second

// retryAttempts returns the attempt budget from E2E_RETRY_ATTEMPTS, or the
// default when the variable is unset or empty. Anything other than a whole
// number of at least 1 is an error, so a typo cannot silently turn retries off.
func retryAttempts() (int, error) {
	raw := strings.TrimSpace(os.Getenv(retryEnv))
	if raw == "" {
		return defaultRetryAttempts, nil
	}
	n, err := strconv.Atoi(raw)
	if err != nil || n < 1 {
		return 0, fmt.Errorf("%s=%q: want a whole number of attempts, at least 1", retryEnv, raw)
	}
	return n, nil
}

// mustRetryAttempts returns the attempt budget, failing the test when
// E2E_RETRY_ATTEMPTS is malformed.
func mustRetryAttempts(t testing.TB) int {
	t.Helper()
	n, err := retryAttempts()
	if err != nil {
		t.Fatal(err)
	}
	return n
}

// retryWait is the pause after the n-th failed attempt, counted from 1: 10s
// after the first failure, 20s after the second, and so on.
func retryWait(n int) time.Duration {
	return time.Duration(n) * retryStep
}

// retry calls attempt with 1, 2, ... until it reports success, at most
// attempts times. attempt returns whether the call succeeded and a detail,
// usually the command's output, which logf receives for every failed attempt.
// After the n-th failed attempt, when another attempt follows, retry pauses for
// wait(n). It returns nil on success, or an error that carries the last detail
// when every attempt failed.
func retry(
	attempts int,
	wait func(n int) time.Duration,
	logf func(format string, args ...any),
	attempt func(n int) (ok bool, detail string),
) error {
	var last string
	for n := 1; n <= attempts; n++ {
		ok, detail := attempt(n)
		if ok {
			return nil
		}
		last = detail
		logf("attempt %d of %d failed:\n%s", n, attempts, detail)
		if n < attempts {
			pause := wait(n)
			logf("retrying in %s", pause)
			time.Sleep(pause)
		}
	}
	return fmt.Errorf("failed after %d attempt(s), last output:\n%s", attempts, last)
}
