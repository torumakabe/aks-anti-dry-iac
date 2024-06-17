package test

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"net/http"
	"net/http/cookiejar"
	"net/netip"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/hashicorp/go-retryablehttp"
	"github.com/hashicorp/go-version"
	"github.com/hashicorp/hc-install/product"
	"github.com/hashicorp/hc-install/releases"
	"github.com/hashicorp/terraform-exec/tfexec"
)

type ResponseBodyIncr struct {
	Hostname string `json:"hostname"`
	Count    int    `json:"count"`
}

type aksCluster struct {
	rgName      string
	clusterName string
}

type endpointTestConfig struct {
	IP                 netip.Addr
	chaosTestManifests []string
	cardinarity        int
	prepTimeout        time.Duration
	testDuration       time.Duration
}

var (
	scope              = flag.String("scope", "all", "specify test scope [blue/green/all]")
	tfVer              = flag.String("tf-version", "1.8.5", "specify Terraform version")
	chaosTestManifests = flag.String("chaostest-manifest", "../chaos/manifests/*.yaml", "specify chaos test manifest file path")
)

var waitOnce sync.Once

func init() {
	testing.Init()
	flag.Parse()
}

func TestE2E(t *testing.T) {
	err := checkEnv(t)
	if err != nil {
		t.Fatal(err)
	}

	clusters := map[string]aksCluster{}
	switch *scope {
	case "blue":
		clusters["blue"] = aksCluster{}
	case "green":
		clusters["green"] = aksCluster{}
	case "all":
		clusters["blue"] = aksCluster{}
		clusters["green"] = aksCluster{}
	default:
		t.Fatalf("Please specify [blue/green/all] as scope")
	}

	pattern := *chaosTestManifests
	var absManifestPaths []string
	paths, err := filepath.Glob(pattern)
	if err != nil {
		t.Fatal(err)
	}

	if len(paths) > 0 {
		for _, path := range paths {
			p, err := filepath.Abs(path)
			if err != nil {
				t.Fatal(err)
			}
			absManifestPaths = append(absManifestPaths, p)
		}
		t.Logf("Chaos test manifests: %s", absManifestPaths)
	} else {
		t.Logf("Chaos test nanifests not found: %s", pattern)
	}

	execPath, err := installTF(t)
	if err != nil {
		t.Fatal(err)
	}

	t.Cleanup(func() {
		t.Log("Destroying shared infrastructure...")
		err = destroyShared(t, "../fixtures/shared", execPath, "./e2e.tfvars")
		if err != nil {
			t.Errorf("An error occuered while destroying shared resources. Manual removal might be required including dependent AKS resources: %s", err)
		}
	})

	t.Log("Setting up shared infrastructure...")
	endpoint, err := setupShared(t, "../fixtures/shared", execPath, "./e2e.tfvars")
	if err != nil {
		t.Fatal(err)
	}

	t.Cleanup(func() {
		// destroy AKS cluster in parallel
		var wg sync.WaitGroup
		for cluster := range clusters {
			cluster := cluster
			wd := fmt.Sprintf("../fixtures/%s", cluster)
			wg.Add(1)
			go func() {
				defer wg.Done()
				t.Logf("Destroying AKS cluster (%s)...", cluster)
				err = destroyAKS(t, wd, execPath, "./e2e.tfvars")
				if err != nil {
					t.Errorf("An error occuered while destroying AKS cluster (%s). Manual removal might be required including dependent shared resources: %s", cluster, err)
				}
			}()
		}
		wg.Wait()
	})

	// setup AKS cluster in parallel
	var mutex = &sync.Mutex{}
	r := t.Run("setupAKS", func(t *testing.T) {
		for cluster := range clusters {
			cluster := cluster
			tn := fmt.Sprintf("setup%s", cluster)
			wd := fmt.Sprintf("../fixtures/%s", cluster)
			r := t.Run(tn, func(t *testing.T) {
				t.Logf("Setting up AKS cluster (%s)...", cluster)
				rgName, clusterName, err := setupAKS(t, wd, execPath, "./e2e.tfvars")
				if err != nil {
					t.Fatal(err)
				}
				mutex.Lock()
				clusters[cluster] = aksCluster{rgName: rgName, clusterName: clusterName}
				mutex.Unlock()
			})
			if !r {
				t.Fatalf("Setting up AKS cluster (%s) failed", cluster)
			}
		}
	})
	if !r {
		t.Fatal("Setting up AKS cluster(s) failed")
	}

	endpointIP, err := netip.ParseAddr(endpoint)
	if err != nil {
		t.Fatal(err)
	}
	cardinarity := 4
	if *scope != "all" {
		cardinarity = 2
	}
	config := &endpointTestConfig{
		IP:                 endpointIP,
		cardinarity:        cardinarity,
		prepTimeout:        30 * time.Minute,
		testDuration:       2 * time.Minute,
		chaosTestManifests: absManifestPaths,
	}

	t.Log("Testing endpoint...")
	err = testEndpoint(t, config, clusters)
	if err != nil {
		t.Fatal(err)
	}

	t.Log("Testing completed.")
}

// checkEnv chcek environment variables for Flux
func checkEnv(t *testing.T) error {
	t.Helper()

	gh_token := os.Getenv("TF_VAR_flux_git_token")
	if gh_token == "" {
		return fmt.Errorf("You must export GITHUB_TOKEN or TF_VAR_flux_git_token")
	}

	gh_user := os.Getenv("TF_VAR_flux_git_user")
	if gh_user == "" {
		return fmt.Errorf("You must export GITHUB_USER or TF_VAR_flux_git_user")
	}

	// check login status
	cmd := exec.Command("az", "account", "list-locations")
	_ = cmd.Run()
	exitCode := cmd.ProcessState.ExitCode()
	if exitCode != 0 {
		return fmt.Errorf("You must login to Azure with Azure CLI")
	}

	return nil
}

func installTF(t *testing.T) (string, error) {
	t.Helper()

	installer := &releases.ExactVersion{
		Product: product.Terraform,
		Version: version.Must(version.NewVersion(*tfVer)),
	}

	t.Cleanup(func() {
		err := installer.Remove(context.Background())
		if err != nil {
			t.Error(err)
		}
	})

	execPath, err := installer.Install(context.Background())
	if err != nil {
		return "", fmt.Errorf("install tf: %w", err)
	}

	return execPath, nil
}

func setupShared(t *testing.T, workingDir, execPath, varFile string) (string, error) {
	t.Helper()

	tf, err := tfexec.NewTerraform(workingDir, execPath)
	if err != nil {
		return "", fmt.Errorf("new tf: %w", err)
	}

	err = tf.Init(context.Background(), tfexec.Upgrade(true))
	if err != nil {
		return "", fmt.Errorf("tf init: %w", err)
	}

	err = tf.Apply(context.Background(), tfexec.VarFile(varFile))
	if err != nil {
		return "", fmt.Errorf("tf apply: %w", err)
	}

	state, err := tf.Show(context.Background())
	if err != nil {
		return "", fmt.Errorf("tf show: %w", err)
	}

	return state.Values.Outputs["demoapp_public_endpoint_ip"].Value.(string), nil
}

func destroyShared(t *testing.T, workingDir, execPath, varFile string) error {
	t.Helper()

	tf, err := tfexec.NewTerraform(workingDir, execPath)
	if err != nil {
		return fmt.Errorf("new tf: %w", err)
	}

	err = tf.Destroy(context.Background(), tfexec.VarFile(varFile))
	if err != nil {
		return fmt.Errorf("tf destroy: %w", err)
	}

	return nil
}

func setupAKS(t *testing.T, workingDir, execPath, varFile string) (string, string, error) {
	t.Helper()
	t.Parallel()

	sl := strings.Split(workingDir, "/")
	clusterSwitch := sl[len(sl)-1]

	waitOnce.Do(func() {
		s := 120 * time.Second
		t.Logf("%s wait %v to avoid conflictling shared resource operations like VNet", clusterSwitch, s)
		time.Sleep(s)
	})

	tf, err := tfexec.NewTerraform(workingDir, execPath)
	if err != nil {
		return "", "", fmt.Errorf("new tf: %w", err)
	}

	err = tf.Init(context.Background(), tfexec.Upgrade(true))
	if err != nil {
		return "", "", fmt.Errorf("tf init: %w", err)
	}

	err = tf.Apply(context.Background(), tfexec.VarFile(varFile), tfexec.Parallelism(1))
	if err != nil {
		return "", "", fmt.Errorf("tf apply: %w", err)
	}

	state, err := tf.Show(context.Background())
	if err != nil {
		return "", "", fmt.Errorf("tf show: %w", err)
	}

	rgName := state.Values.Outputs["resource_group_name"].Value.(string)
	clusterName := state.Values.Outputs["aks_cluster_name"].Value.(string)

	return rgName, clusterName, nil
}

func destroyAKS(t *testing.T, workingDir, execPath, varFile string) error {
	t.Helper()

	tf, err := tfexec.NewTerraform(workingDir, execPath)
	if err != nil {
		return fmt.Errorf("new tf: %w", err)
	}

	err = tf.Destroy(context.Background(), tfexec.VarFile(varFile))
	if err != nil {
		return fmt.Errorf("tf destroy: %w", err)
	}

	return nil
}

func testEndpoint(t *testing.T, config *endpointTestConfig, clusters map[string]aksCluster) error {
	t.Helper()

	// Test that Pods started as expected
	err := testPodCardinarity(t, config)
	if err != nil {
		return err
	}

	// Test incrementing the count with session
	ctx := context.Background()
	ctx, cancel := context.WithCancel(ctx)
	defer cancel()
	readyChan := make(chan struct{})
	errChan := make(chan error)
	defer close(errChan)
	go func(ctx context.Context) {
		err := testSession(t, ctx, config, readyChan)
		if !errors.Is(err, errors.New("canceled")) {
			errChan <- err
		}
	}(ctx)

	// Wait until session test setup is ready (readyChan closed) for addtional test
	_, open := <-readyChan
	if !open {
		// Additional test: Test resiliency with chaos injection
		if len(config.chaosTestManifests) > 0 {
			err = injectChaos(t, config, clusters)
			if err != nil {
				errChan <- err
			}
		}
	}

	// Wait until session test completes or returns error
	err = <-errChan
	if err != nil {
		return err
	}

	return nil
}

func testPodCardinarity(t *testing.T, config *endpointTestConfig) error {
	t.Helper()

	url := fmt.Sprintf("http://%s/incr", config.IP.String())
	retryClient := retryablehttp.NewClient()
	retryClient.RetryMax = 50
	retryClient.Logger = nil
	standardClient := retryClient.StandardClient()

	// Wait until Pod cardinarity reaches the expected value with timeout
	ctx, cancel := context.WithTimeout(context.Background(), config.prepTimeout)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return fmt.Errorf("new http req: %w", err)
	}

	hostSet := make(map[string]struct{})
	timeout := time.After(config.prepTimeout)
	t.Logf("Waiting until the endpoint is ready. Timeout in %s", config.prepTimeout)
loop:
	for i := 0; ; i++ {
		select {
		case <-timeout:
			return fmt.Errorf("tried for %s but did not reach the specified cardinarity of pods: %d / %d", config.prepTimeout, len(hostSet), config.cardinarity)
		default:
			resp, err := standardClient.Do(req)
			if err != nil {
				if errors.Is(err, context.DeadlineExceeded) && i == 0 {
					return fmt.Errorf("tried to connect for %s but faild. maybe appgw/backend is not ready", config.prepTimeout)
				}
				return fmt.Errorf("get endpoint: %w", err)
			}
			defer resp.Body.Close()

			if resp.StatusCode != http.StatusOK {
				resp.Body.Close()
				t.Logf("Waiting for all Pods (%d/%d) to respond: %d attempt(s)", len(hostSet), config.cardinarity, i+1)
				time.Sleep(time.Second * 10)
				continue
			}

			body, err := io.ReadAll(resp.Body)
			if err != nil {
				return fmt.Errorf("read body: %w", err)
			}

			var r ResponseBodyIncr
			err = json.Unmarshal(body, &r)
			if err != nil {
				return fmt.Errorf("unmarshal body: %w", err)
			}
			hostSet[r.Hostname] = struct{}{}
			if len(hostSet) == config.cardinarity {
				t.Logf("All Pods (%d/%d) respond successfully", len(hostSet), config.cardinarity)
				break loop
			}

			resp.Body.Close()
			t.Logf("Waiting for all Pods (%d/%d) to respond: %d attempt(s)", len(hostSet), config.cardinarity, i+1)
			time.Sleep(time.Second * 10)
		}
	}

	return nil
}

func testSession(t *testing.T, ctx context.Context, config *endpointTestConfig, readyChan chan struct{}) error {
	t.Helper()

	url := fmt.Sprintf("http://%s/incr", config.IP.String())
	retryClient := retryablehttp.NewClient()
	retryClient.RetryMax = 10
	retryClient.Logger = nil
	standardClient := retryClient.StandardClient()
	jar, _ := cookiejar.New(nil)
	standardClient.Jar = jar

	timeout := time.After(config.testDuration)
	t.Logf("Session test started. The duration is %s", config.testDuration)
	var countMemo int
	for i := 0; ; i++ {
		select {
		case <-timeout:
			t.Logf("Got the expected response successfully for %s", config.testDuration)
			return nil
		case <-ctx.Done():
			return errors.New("canceled")
		default:
			resp, err := standardClient.Get(url)
			if err != nil {
				return fmt.Errorf("get endpoint: %w", err)
			}
			defer resp.Body.Close()

			body, err := io.ReadAll(resp.Body)
			if err != nil {
				return fmt.Errorf("read body: %w", err)
			}

			var r ResponseBodyIncr
			err = json.Unmarshal(body, &r)
			if err != nil {
				return fmt.Errorf("unmarshal body: %w", err)
			}

			if i == 0 {
				countMemo = r.Count
				close(readyChan)
				continue
			}
			if (r.Count - countMemo) != 1 {
				return fmt.Errorf("counter increment with session did not work. last: %d, received: %d", countMemo, r.Count)
			}
			countMemo = r.Count
		}
	}
}

// TODO: Replace this function to Azure Chaos Studio for flexible experiment control such as step/branch
// This function simply executes manifests in succession with equal interval at this time
func injectChaos(t *testing.T, config *endpointTestConfig, clusters map[string]aksCluster) error {
	t.Helper()

	t.Cleanup(func() {
		scriptPath := "../chaos/scripts/cleanup.sh"
		for k, v := range clusters {
			t.Logf("Cleaning up the chaos from %s", k)
			for _, manifest := range config.chaosTestManifests {
				cmd := exec.Command(scriptPath, v.rgName, v.clusterName, manifest)
				cmd.Env = os.Environ()
				var outb, errb bytes.Buffer
				cmd.Stdout = &outb
				cmd.Stderr = &errb
				err := cmd.Run()
				if err != nil {
					// logging only (not critical)
					t.Log(err)
					t.Log(outb.String())
					t.Log(errb.String())
				}
			}
		}
	})

	// Calculate equal interval to apply chaos test manifests
	interval := config.testDuration / time.Duration(len(config.chaosTestManifests)*len(clusters)+1)

	scriptPath := "../chaos/scripts/inject.sh"
	for k, v := range clusters {
		t.Logf("Injecting the chaos to %s", k)
		for _, manifest := range config.chaosTestManifests {
			cmd := exec.Command(scriptPath, v.rgName, v.clusterName, manifest)
			cmd.Env = os.Environ()
			var outb, errb bytes.Buffer
			cmd.Stdout = &outb
			cmd.Stderr = &errb
			err := cmd.Run()
			if err != nil {
				t.Log(outb.String())
				t.Log(errb.String())
				return fmt.Errorf("inject fault: %w", err)
			}
			t.Logf("Applied manifest %s to %s successfully", manifest, v.clusterName)
			time.Sleep(interval)
		}
	}

	return nil
}
