
variable "PUBLISHER"  { default = "yottalabsai" }
variable "TAG_SUFFIX" { default = "latest" }
variable "BASE_IMAGE" { default = "radixark/miles:latest" }

group "default" {
  targets = ["miles"]
}

target "miles" {
  dockerfile  = "Dockerfile"
  platforms   = ["linux/amd64"]
  
  tags = [
    "${PUBLISHER}/miles-yotta:${TAG_SUFFIX}",
  ]
  
  contexts = {
    scripts = "../../container-template"
    proxy   = "../../container-template/proxy"
    logo    = "../../container-template"
  }
    
  args = {
    BASE_IMAGE = "${BASE_IMAGE}"
  }
}
