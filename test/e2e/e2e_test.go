package test

import (
	"bytes"
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"io/ioutil"
	"net/http/cookiejar"
	"os"
	"os/exec"
	"strings"
	"testing"
	"time"

	"github.com/hashicorp/go-retryablehttp"
	"github.com/hashicorp/go-version"
	"github.com/hashicorp/hc-install/product"
	"github.com/hashicorp/hc-install/releases"
	"github.com/hashicorp/terraform-exec/tfexec"
)

type ResponseBodyIncr struct {
	Count    int    `json:"count"`
	Hostname string `json:"hostname"`
}

var (
	scope      = flag.String("scope", "all", "specify target cluster [blue/green/all]")
	tfVer      = flag.String("tf-version", "1.1.7", "specify Terraform version")
	fluxURL    = flag.String("flux-repo-url", "", "specify Flux Repo URL [https://your-repo.git]")
	fluxBranch = flag.String("flux-branch", "", "specify Flux branch")
)

func init() {
	testing.Init()
	flag.Parse()
}

func TestE2E(t *testing.T) {
	err := checkEnv(t)
	if err != nil {
		t.Fatal(err)
	}

	var targets []string
	switch *scope {
	case "blue":
		targets = append(targets, "blue")
	case "green":
		targets = append(targets, "green")
	case "all":
		targets = append(targets, "blue", "green")
	default:
		t.Fatalf("Please specify [blue/green/all] as scope")
	}

	execPath, err := installTF(t)
	if err != nil {
		t.Fatal(err)
	}

	t.Cleanup(func() {
		t.Log("Destroying shared infrastructure...")
		err = destroyShared(t, "../fixtures/shared", execPath, "./e2e.tfvars")
		if err != nil {
			t.Fatal(err)
		}
	})

	t.Log("Setting up shared infrastructure...")
	endpoint, err := setupShared(t, "../fixtures/shared", execPath, "./e2e.tfvars")
	if err != nil {
		t.Fatal(err)
	}
	t.Logf("\nendpoint: %s", endpoint)

	t.Cleanup(func() {
		// destroy AKS cluster in parallel
		t.Run("destroyAKS", func(t *testing.T) {
			for _, target := range targets {
				target := target
				tn := fmt.Sprintf("destroy%s", target)
				wd := fmt.Sprintf("../fixtures/%s", target)
				t.Run(tn, func(t *testing.T) {
					t.Logf("Destroying AKS cluster (%s)...", target)
					err = destroyAKS(t, wd, execPath, "./e2e.tfvars")
					if err != nil {
						t.Fatal(err)
					}
				})
			}
		})
	})

	// setup AKS cluster in parallel
	s := t.Run("setupAKS", func(t *testing.T) {
		for _, target := range targets {
			target := target
			tn := fmt.Sprintf("setup%s", target)
			wd := fmt.Sprintf("../fixtures/%s", target)
			s := t.Run(tn, func(t *testing.T) {
				t.Logf("Setting up AKS cluster (%s)...", target)
				err = setupAKS(t, wd, execPath, "./e2e.tfvars")
				if err != nil {
					t.Error(err)
				}
			})
			if !s {
				t.Errorf("Setting up AKS cluster (%s) failed", target)
			}
		}
	})

	if !s {
		t.Fatal("Setting up AKS cluster failed")
	}

	cardinarity := 4
	if *scope != "all" {
		cardinarity = 2
	}

	t.Log("Testing endpoint...")
	err = testEndpoint(t, endpoint, cardinarity, 100, true)
	if err != nil {
		t.Error(err)
	}

	t.Log("Testing completed.")
}

// checkEnv chcek environment variables for Flux
func checkEnv(t *testing.T) error {
	t.Helper()
	gh_token := os.Getenv("GITHUB_TOKEN")
	if gh_token == "" {
		return fmt.Errorf("You must export GITHUB_TOKEN")
	}

	gh_user := os.Getenv("GITHUB_USER")
	if gh_user == "" {
		return fmt.Errorf("You must export GITHUB_USER")
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
		installer.Remove(context.Background())
	})

	execPath, err := installer.Install(context.Background())
	if err != nil {
		return "", err
	}

	return execPath, nil
}

func setupShared(t *testing.T, workingDir, execPath, varFile string) (string, error) {
	t.Helper()

	tf, err := tfexec.NewTerraform(workingDir, execPath)
	if err != nil {
		return "", err
	}

	err = tf.Init(context.Background(), tfexec.Upgrade(true))
	if err != nil {
		return "", err
	}

	err = tf.Apply(context.Background(), tfexec.VarFile(varFile))
	if err != nil {
		return "", err
	}

	state, err := tf.Show(context.Background())
	if err != nil {
		return "", err
	}

	return state.Values.Outputs["demoapp_public_endpoint_ip"].Value.(string), nil
}

func destroyShared(t *testing.T, workingDir, execPath, varFile string) error {
	t.Helper()

	tf, err := tfexec.NewTerraform(workingDir, execPath)
	if err != nil {
		return err
	}

	err = tf.Destroy(context.Background(), tfexec.VarFile(varFile))
	if err != nil {
		t.Error(err)
	}

	return nil
}

func setupAKS(t *testing.T, workingDir, execPath, varFile string) error {
	t.Helper()
	t.Parallel()

	sl := strings.Split(workingDir, "/")
	clusterSwitch := sl[len(sl)-1]

	tf, err := tfexec.NewTerraform(workingDir, execPath)
	if err != nil {
		return err
	}

	err = tf.Init(context.Background(), tfexec.Upgrade(true))
	if err != nil {
		return err
	}

	err = tf.Apply(context.Background(), tfexec.VarFile(varFile))
	if err != nil {
		return err
	}

	state, err := tf.Show(context.Background())
	if err != nil {
		return err
	}

	rgName := state.Values.Outputs["resource_group_name"].Value.(string)
	clusterName := state.Values.Outputs["aks_cluster_name"].Value.(string)

	bsScriptPath := "../../flux/scripts/setup-dev-test.sh"
	cmd := exec.Command(bsScriptPath, clusterSwitch, rgName, clusterName, *fluxURL, *fluxBranch)
	cmd.Env = os.Environ()
	var outb, errb bytes.Buffer
	cmd.Stdout = &outb
	cmd.Stderr = &errb
	err = cmd.Run()
	if err != nil {
		t.Log(outb.String())
		t.Log(errb.String())
		return err
	}

	return nil
}

func destroyAKS(t *testing.T, workingDir, execPath, varFile string) error {
	t.Helper()
	t.Parallel()

	tf, err := tfexec.NewTerraform(workingDir, execPath)
	if err != nil {
		return err
	}

	err = tf.Destroy(context.Background(), tfexec.VarFile(varFile))
	if err != nil {
		t.Error(err)
	}

	return nil
}

func testEndpoint(t *testing.T, endpoint string, cardinarity, attempts int, cookieTest bool) error {
	t.Helper()
	url := fmt.Sprintf("http://%s/incr", endpoint)
	retryClient := retryablehttp.NewClient()
	retryClient.RetryMax = 50

	hostSet := make(map[string]struct{})
	for i := 0; i < attempts; i++ {
		resp, err := retryClient.Get(url)
		if err != nil {
			return err
		}
		defer resp.Body.Close()

		body, err := ioutil.ReadAll(resp.Body)
		if err != nil {
			return err
		}
		t.Log(string(body))

		var r ResponseBodyIncr
		err = json.Unmarshal(body, &r)
		if err != nil {
			return err
		}
		hostSet[r.Hostname] = struct{}{}
		if len(hostSet) == cardinarity {
			break
		}
		time.Sleep(time.Second * 5)
	}
	if len(hostSet) < cardinarity {
		return fmt.Errorf("tried %d times but did not reach the specified cardinarity of pods: %d pods", attempts, cardinarity)
	}

	// Test incremting the count with cookie
	if cookieTest {
		standardClient := retryClient.StandardClient()
		jar, _ := cookiejar.New(nil)
		standardClient.Jar = jar

		var countMemo int
		for i := 0; i < 10; i++ {
			resp, err := standardClient.Get(url)
			if err != nil {
				return err
			}
			defer resp.Body.Close()

			body, err := ioutil.ReadAll(resp.Body)
			if err != nil {
				return err
			}
			t.Log(string(body))

			var r ResponseBodyIncr
			err = json.Unmarshal(body, &r)
			if err != nil {
				return err
			}

			if i == 0 {
				countMemo = r.Count
				continue
			}
			if (r.Count - countMemo) != 1 {
				return fmt.Errorf("persistent cookie did not work")
			}
			countMemo = r.Count
		}
	}

	return nil
}
