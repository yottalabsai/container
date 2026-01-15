variable "PUBLISHER"  { default = "yottalabsai" }
variable "TAG"        { default = "latest" }

group "default" {
  targets = ["gateway"]
}

target "gateway" {
  platforms  = ["linux/amd64"]
  dockerfile = "Dockerfile"
  tags = [
    "${PUBLISHER}/go-model-gateway:${TAG}"
  ]
}
