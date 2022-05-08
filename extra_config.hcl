client {
  cni_path = "/nix/store/8qlcms1gwm9bf5nwfpfk3lgywb68sand-cni-plugins-1.1.1/bin/"
}

plugin "nomad-driver-containerd" {
  config {
    enabled = true
    containerd_runtime = "io.containerd.runc.v2"
    stats_interval = "5s"
  }
}
