variable "RELEASE" {
    default = "3.3.0"
}

target "default" {
    dockerfile = "Dockerfile"
    tags = ["yottalabs/stable-diffusion:invoke-${RELEASE}"]
    contexts = {
        scripts = "../../container-template"
        proxy = "../../container-template/proxy"
    }
}
