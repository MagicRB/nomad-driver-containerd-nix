job "hello" {
  datacenters = ["dc1"]

  group "hello-group" {
    # network {
    #   mode = "bridge"
    #   port "http" {
    # 	static = 80
    # 	to = 80
    #   }
    # }
    task "hello-task" {
      driver = "containerd-driver"

      config {
	flake_ref = "git+http://gitea.redalder.org/RedAlder/systems#nixngSystems.website.config.system.build.toplevel"
	flake_sha = "sha256-+muNSb2JOG1Gps5Xm7BsOSHoJPMEERdUXkp3UM4mhJA="
	entrypoint = [ "init" ]
      }

      
      
      resources {
        cpu    = 500
        memory = 256
      }
    }
  }
}
