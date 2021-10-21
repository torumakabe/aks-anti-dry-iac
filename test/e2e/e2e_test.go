package test

import (
	"context"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http/cookiejar"
	"os"
	"os/exec"
	"strings"
	"testing"
	"time"

	"github.com/hashicorp/go-retryablehttp"
	"github.com/hashicorp/terraform-exec/tfexec"
	"github.com/hashicorp/terraform-exec/tfinstall"
)

type ResponseBodyIncr struct {
	Count    int    `json:"count"`
	Hostname string `json:"hostname"`
}

func TestE2EBlue(t *testing.T) {
	err := checkEnv(t)
	if err != nil {
		t.Fatal(err)
	}

	t.Log("Setting up shared infrastructure...")
	endpoint, err := setupShared(t, "../fixtures/shared", "./test.tfvars")
	if err != nil {
		t.Fatal(err)
	}
	t.Logf("\nendpoint: %s", endpoint)

	t.Log("Setting up AKS cluster (blue)...")
	err = setupAKS(t, "../fixtures/blue", "./test.tfvars")
	if err != nil {
		t.Fatal(err)
	}

	t.Log("Testing endpoint...")
	err = testEndpoint(t, endpoint, 2, 100, true)
	if err != nil {
		t.Error(err)
	}

	t.Log("Testing completed.")
}

func TestE2EGreen(t *testing.T) {
	err := checkEnv(t)
	if err != nil {
		t.Fatal(err)
	}

	t.Log("Setting up shared infrastructure...")
	endpoint, err := setupShared(t, "../fixtures/shared", "./test.tfvars")
	if err != nil {
		t.Fatal(err)
	}
	t.Logf("\nendpoint: %s", endpoint)

	t.Log("Setting up AKS cluster (green)...")
	err = setupAKS(t, "../fixtures/green", "./test.tfvars")
	if err != nil {
		t.Fatal(err)
	}

	t.Log("Testing endpoint...")
	err = testEndpoint(t, endpoint, 2, 100, true)
	if err != nil {
		t.Error(err)
	}

	t.Log("Testing completed.")
}

func TestE2EAll(t *testing.T) {
	err := checkEnv(t)
	if err != nil {
		t.Fatal(err)
	}

	t.Log("Setting up shared infrastructure...")
	endpoint, err := setupShared(t, "../fixtures/shared", "./test.tfvars")
	if err != nil {
		t.Fatal(err)
	}
	t.Logf("\nendpoint: %s", endpoint)

	t.Log("Setting up AKS cluster (blue)...")
	err = setupAKS(t, "../fixtures/blue", "./test.tfvars")
	if err != nil {
		t.Fatal(err)
	}

	t.Log("Setting up AKS cluster (green)...")
	err = setupAKS(t, "../fixtures/green", "./test.tfvars")
	if err != nil {
		t.Fatal(err)
	}

	t.Log("Testing endpoint...")
	err = testEndpoint(t, endpoint, 4, 100, true)
	if err != nil {
		t.Error(err)
	}

	t.Log("Testing completed.")
}

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

func setupShared(t *testing.T, workingDir, varFile string) (string, error) {
	t.Helper()
	tmpDir, err := ioutil.TempDir("", "tfinstall")
	if err != nil {
		return "", err
	}
	t.Cleanup(func() { os.RemoveAll(tmpDir) })

	ctx := context.Background()
	latestVersion := tfinstall.LatestVersion(tmpDir, false)
	execPath, err := tfinstall.Find(ctx, latestVersion)
	if err != nil {
		return "", err
	}

	tf, err := tfexec.NewTerraform(workingDir, execPath)
	if err != nil {
		return "", err
	}

	err = tf.Init(ctx, tfexec.Upgrade(true))
	if err != nil {
		return "", err
	}

	t.Cleanup(func() {
		t.Log("Destroying shared infrastructure...")
		err = tf.Destroy(ctx, tfexec.VarFile(varFile))
		if err != nil {
			t.Error(err)
		}
	})

	err = tf.Apply(ctx, tfexec.VarFile(varFile))
	if err != nil {
		return "", err
	}

	state, err := tf.Show(context.Background())
	if err != nil {
		return "", err
	}

	return state.Values.Outputs["demoapp_endpoint_ip"].Value.(string), nil
}

func setupAKS(t *testing.T, workingDir, varFile string) error {
	t.Helper()
	sl := strings.Split(workingDir, "/")
	clusterSwitch := sl[len(sl)-1]

	tmpDir, err := ioutil.TempDir("", "tfinstall")
	if err != nil {
		return err
	}
	t.Cleanup(func() { os.RemoveAll(tmpDir) })

	ctx := context.Background()
	latestVersion := tfinstall.LatestVersion(tmpDir, false)
	execPath, err := tfinstall.Find(ctx, latestVersion)
	if err != nil {
		return err
	}

	tf, err := tfexec.NewTerraform(workingDir, execPath)
	if err != nil {
		return err
	}

	err = tf.Init(ctx, tfexec.Upgrade(true))
	if err != nil {
		return err
	}

	t.Cleanup(func() {
		t.Logf("Destroying AKS cluster: %s...", clusterSwitch)
		err = tf.Destroy(ctx, tfexec.VarFile(varFile))
		if err != nil {
			t.Error(err)
		}
	})

	err = tf.Apply(ctx, tfexec.VarFile(varFile))
	if err != nil {
		return err
	}

	state, err := tf.Show(context.Background())
	if err != nil {
		return err
	}

	rgName := state.Values.Outputs["resource_group_name"].Value.(string)
	clusterName := state.Values.Outputs["aks_cluster_name"].Value.(string)

	bsScriptPath := "../../flux/scripts/bootstrap.sh"
	cmd := exec.Command(bsScriptPath, clusterSwitch, rgName, clusterName)
	cmd.Env = os.Environ()
	err = cmd.Run()
	if err != nil {
		return err
	}

	t.Cleanup(func() {
		ucScriptPath := "../../flux/scripts/usecontext.sh"
		cmd := exec.Command(ucScriptPath, rgName, clusterName)
		cmd.Env = os.Environ()
		err = cmd.Run()
		if err != nil {
			t.Error(err)
		}
	})

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
