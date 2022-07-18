job "hello" {
  datacenters = ["dc1"]

  group "hello-group" {
    network {
      mode = "bridge"
      port "http" {
    	static = 80
    	to = 80
      }
    }
    task "hello-task" {
      driver = "containerd-driver"

      config {
	flake_ref = "git+https://git.irunx.org/MagicRB/ra-systems?rev=b0de53e57fd0926586a975ecb0119c54b2750cbd#nixngSystems.website.config.system.build.toplevel" # "git+http://gitea.redalder.org/RedAlder/systems#nixngSystems.website.config.system.build.toplevel"
	flake_sha = "sha256-2Nw7G1TbGXq3mpmMk2Jt7w3HLUHjkl9MbU1I+8zHdXY=" # "sha256-+muNSb2JOG1Gps5Xm7BsOSHoJPMEERdUXkp3UM4mhJA="
	entrypoint = [ "init" ]
      }

      
      
      resources {
        cpu    = 500
        memory = 256
      }
    }
  }
}
