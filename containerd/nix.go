package containerd

import (
	"fmt"
	"syscall"
	"os/exec"
	"os"
	"strings"
	"encoding/json"
	"github.com/hashicorp/nomad/plugins/drivers"
)

func (d *Driver) NixGetDeps(executable string, flakeRef string) ([]string, error) {
	nixDepsCmd := &exec.Cmd {
		Path: executable,
		Args: []string{
			executable,
			"path-info",
			"-r",
			flakeRef,
		},
	}
	res, err := nixDepsCmd.Output()
	if err != nil {
		return nil, fmt.Errorf("failed to get dependencies of built flake-ref %s", flakeRef)
	}
	deps := strings.Split(strings.Trim(string(res), " \n"), "\n")

	return deps, nil
}

func (d *Driver) NixBuildFlake(executable string, flakeRef string, flakeSha string) error {
	flakeHost := strings.Split(flakeRef, "#")

	if len(flakeHost) != 2 {
		return fmt.Errorf("Invalid flake ref.")
	}

	nixShaCmd := &exec.Cmd {
		Path: executable,
		Args: []string{
			executable,
			"flake",
			"metadata",
			"--json",
			flakeHost[0],
		},
	}
	nixSha, err := nixShaCmd.Output()
	if err != nil {
		return fmt.Errorf("failed to get sha for flake-ref %s with %s:\n %s", flakeRef, err, string(nixSha))
	}

	var shaJson map[string]interface{}
	err = json.Unmarshal(nixSha, &shaJson)

	if err != nil {
		return fmt.Errorf("failed to parse json %s", err)
	}

	lockedVal, ok := shaJson["locked"].(map[string]interface{})
	if !ok {
		return fmt.Errorf("failed to parse `nix flake metadata` output")
	}
	fetchedSha, ok := lockedVal["narHash"].(string)
	if !ok {
		return fmt.Errorf("failed to parse `nix flake metadata` output")
	}

	if string(fetchedSha) != flakeSha {
		return fmt.Errorf("pinned flake sha doesn't match: \"%s\" != \"%s\"", flakeSha, fetchedSha)
	}

	nixBuildCmd := &exec.Cmd {
		Path: executable,
		Args: []string{
			executable,
			"build",
			"--no-link",
			flakeRef,
		},
	}
	res, err := nixBuildCmd.Output()
	if err != nil {
		return fmt.Errorf("failed to build flake-ref %s with %s:\n %s", flakeRef, err, string(res))
	}

	return nil
}

func (d *Driver) NixGetStorePath(executable string, flakeRef string) (string, error) {
	nixEvalCmd := exec.Cmd {
		Path: executable,
		Args: []string{
			executable,
			"eval",
			"--raw",
			flakeRef + ".outPath",
		},
	}

	storePath, err := nixEvalCmd.Output()
	if err != nil {
		return "", fmt.Errorf("failed to get store path of %s", flakeRef)
	}
	return string(storePath), nil
}

func (d *Driver) GetGCRoot(containerName string, allocationId string) string {
	return fmt.Sprintf("%s/%s-%s", d.config.GCRootsRoot, containerName, allocationId)
}

func (d *Driver) GetRootFSPath(containerName string, allocationId string) string {
	return fmt.Sprintf("%s/%s-%s", d.config.RootFSRoot, containerName, allocationId)
}

func (d *Driver) SetupRootFS(flakeRef string, containerName string, allocationId string, flakeSha string) (string, string, error) {
	nixExecutable, err := exec.LookPath("nix")
	if err != nil {
		return "", "", fmt.Errorf("failed to find `nix` executable")
	}

	err = d.NixBuildFlake(nixExecutable, flakeRef, flakeSha)
	if err != nil {
		return "", "", err
	}

	deps, err := d.NixGetDeps(nixExecutable, flakeRef)
	if err != nil {
		return "", "", err
	}

	rootFS := d.GetRootFSPath(containerName, allocationId)
	os.MkdirAll(rootFS, 0755)

	for _, dep := range deps {
		target := fmt.Sprintf("%s%s", rootFS, dep)

		info, err := os.Stat(dep)
		if os.IsNotExist(err) {
			return "", "", fmt.Errorf("store path reported as dep but does no exist %s: %s", dep, err)
		}
		if info.IsDir() {
			os.MkdirAll(target, 0755)
		} else {
			os.Create(target)
		}

		err32 := syscall.Mount(dep, target, "", syscall.MS_BIND, "")
		if err32 != nil {
			return "", "", fmt.Errorf("failed to bind mount store path %s: %v", dep, err)
		}
	}

	storePath, err := d.NixGetStorePath(nixExecutable, flakeRef)
	if err != nil {
		return "", "", err
	}

	// Create GC-Root
	gcRoot := d.GetGCRoot(containerName, allocationId)
	os.MkdirAll(d.config.GCRootsRoot, 0755)

	os.Symlink(storePath, gcRoot)

	return rootFS, deps[len(deps)-1], nil
}

func (d *Driver) DestroyRootFS(driverConfig *TaskConfig, taskConfig *drivers.TaskConfig) error {
	nixExecutable, err := exec.LookPath("nix")
	if err != nil {
		return fmt.Errorf("failed to find `nix` executable")
	}

	deps, err := d.NixGetDeps(nixExecutable, driverConfig.FlakeRef)
	if err != nil {
		return err
	}

	rootFSPath := d.GetRootFSPath(taskConfig.Name, taskConfig.AllocID)

	for _, dep := range deps {
		err := syscall.Unmount(rootFSPath + "/" + dep, 0)
		if err != nil {
			return err
		}
	}


	os.RemoveAll(rootFSPath)

	gcRoot := d.GetGCRoot(taskConfig.Name, taskConfig.AllocID)

	os.Remove(gcRoot)

	return nil
}
