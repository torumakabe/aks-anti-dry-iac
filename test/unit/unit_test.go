package test

import (
	"context"
	"io/ioutil"
	"os"
	"testing"

	"github.com/hashicorp/terraform-exec/tfexec"
	"github.com/hashicorp/terraform-exec/tfinstall"
)

func TestTerraformShared(t *testing.T) {
	t.Parallel()
	workingDir := "../fixtures/shared"
	err := testUnit(t, workingDir, "./test.tfvars")
	if err != nil {
		t.Error(err)
	}
}

func TestTerraformBlue(t *testing.T) {
	t.Parallel()
	workingDir := "../fixtures/blue"
	err := testUnit(t, workingDir, "./test.tfvars")
	if err != nil {
		t.Error(err)
	}
}

func TestTerraformGreen(t *testing.T) {
	t.Parallel()
	workingDir := "../fixtures/green"
	err := testUnit(t, workingDir, "./test.tfvars")
	if err != nil {
		t.Error(err)
	}
}

func testUnit(t *testing.T, workingDir, varFile string) error {
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

	_, err = tf.Plan(ctx, tfexec.VarFile(varFile))
	if err != nil {
		return err
	}

	return nil
}
