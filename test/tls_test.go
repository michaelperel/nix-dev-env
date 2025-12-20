package test

import (
	"crypto/tls"
	"crypto/x509"
	"net/http"
	"os"
	"testing"
	"time"
)

func TestHTTPSRequest(t *testing.T) {
	url := os.Getenv("NET_TEST_URL")
	if url == "" {
		url = "https://www.google.com"
	}

	pool, err := x509.SystemCertPool()
	if err != nil {
		t.Fatalf("SystemCertPool failed: %v", err)
	}

	transport := &http.Transport{
		TLSClientConfig: &tls.Config{RootCAs: pool},
	}
	client := &http.Client{Timeout: 15 * time.Second, Transport: transport}

	resp, err := client.Head(url)
	if err != nil {
		// Some hosts block HEAD; fall back to GET.
		resp, err = client.Get(url)
	}
	if err != nil {
		t.Fatalf("TLS/HTTPS request failed: %v", err)
	}
	resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 500 {
		t.Fatalf("unexpected HTTP status: %s", resp.Status)
	}
}
