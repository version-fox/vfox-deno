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
	"strings"
	"testing"
	"time"
)

// collect returns a logf that appends each formatted message to lines.
func collect(lines *[]string) func(format string, args ...any) {
	return func(format string, args ...any) {
		*lines = append(*lines, fmt.Sprintf(format, args...))
	}
}

// noWait is a backoff that does not pause, for tests.
func noWait(int) time.Duration { return 0 }

// TestRetryAttemptsFromEnv checks how E2E_RETRY_ATTEMPTS is read: an unset or
// empty value gives the default, a whole number of at least 1 is taken as it
// is, and anything else is an error. It runs under -short.
func TestRetryAttemptsFromEnv(t *testing.T) {
	cases := []struct {
		name    string
		env     string
		want    int
		wantErr bool
	}{
		{name: "unset", env: "", want: defaultRetryAttempts},
		{name: "explicit", env: "5", want: 5},
		{name: "one attempt", env: " 1 ", want: 1},
		{name: "zero", env: "0", wantErr: true},
		{name: "negative", env: "-2", wantErr: true},
		{name: "not a number", env: "three", wantErr: true},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			t.Setenv(retryEnv, tc.env)
			got, err := retryAttempts()
			if (err != nil) != tc.wantErr {
				t.Fatalf("retryAttempts() error = %v, want error %v", err, tc.wantErr)
			}
			if got != tc.want {
				t.Errorf("retryAttempts() = %d, want %d", got, tc.want)
			}
		})
	}
}

// TestRetryWaitIsLinear checks the backoff: 10s after the first failure, 20s
// after the second, 30s after the third. It runs under -short.
func TestRetryWaitIsLinear(t *testing.T) {
	want := map[int]time.Duration{1: 10 * time.Second, 2: 20 * time.Second, 3: 30 * time.Second}
	for n, d := range want {
		if got := retryWait(n); got != d {
			t.Errorf("retryWait(%d) = %s, want %s", n, got, d)
		}
	}
}

// TestRetryStopsAtFirstSuccess checks that retry stops when an attempt succeeds
// and logs the output of each failed attempt before it. It runs under -short.
func TestRetryStopsAtFirstSuccess(t *testing.T) {
	var logs []string
	calls := 0
	err := retry(3, noWait, collect(&logs), func(n int) (bool, string) {
		calls++
		return n == 2, fmt.Sprintf("output of attempt %d", n)
	})
	if err != nil {
		t.Fatalf("retry: %v", err)
	}
	if calls != 2 {
		t.Errorf("attempts = %d, want 2", calls)
	}
	if len(logs) == 0 || !strings.Contains(logs[0], "attempt 1 of 3 failed") || !strings.Contains(logs[0], "output of attempt 1") {
		t.Errorf("logs = %q, want attempt 1's output logged as failed", logs)
	}
}

// TestRetryExhaustsAndLogsEveryFailure checks that when every attempt fails,
// retry makes the full budget of attempts, logs each one's output, and returns
// an error with the last output. It runs under -short.
func TestRetryExhaustsAndLogsEveryFailure(t *testing.T) {
	var logs []string
	calls := 0
	err := retry(3, noWait, collect(&logs), func(n int) (bool, string) {
		calls++
		return false, fmt.Sprintf("failure %d", n)
	})
	if calls != 3 {
		t.Errorf("attempts = %d, want 3", calls)
	}
	if err == nil || !strings.Contains(err.Error(), "failure 3") {
		t.Fatalf("retry error = %v, want one that carries the last output", err)
	}
	joined := strings.Join(logs, "\n")
	for n := 1; n <= 3; n++ {
		if !strings.Contains(joined, fmt.Sprintf("failure %d", n)) {
			t.Errorf("logs do not carry the output of attempt %d:\n%s", n, joined)
		}
	}
}

// TestRetryPausesOnlyBetweenAttempts checks the pauses: one after attempt 1 and
// one after attempt 2 of 3, none after the last. It runs under -short.
func TestRetryPausesOnlyBetweenAttempts(t *testing.T) {
	var waits []int
	wait := func(n int) time.Duration {
		waits = append(waits, n)
		return 0
	}
	var logs []string
	_ = retry(3, wait, collect(&logs), func(int) (bool, string) { return false, "no" })
	if fmt.Sprint(waits) != "[1 2]" {
		t.Errorf("pauses were taken after attempts %v, want [1 2]", waits)
	}
}

// TestRetryWithNoAttemptsCallsNothing checks that a zero budget is an error
// and runs no attempt. It runs under -short.
func TestRetryWithNoAttemptsCallsNothing(t *testing.T) {
	calls := 0
	err := retry(0, noWait, func(string, ...any) {}, func(int) (bool, string) {
		calls++
		return true, ""
	})
	if calls != 0 || err == nil {
		t.Fatalf("retry(0): calls = %d, error = %v; want no calls and an error", calls, err)
	}
}
