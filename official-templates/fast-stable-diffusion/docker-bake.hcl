variable "RELEASE" {
    default = "2.4.0"
}

target "default" {
    dockerfile = "Dockerfile"
    tags = ["yottalabs/stable-diffusion:fast-stable-diffusion-${RELEASE}"]
    contexts = {
        scripts = "../../container-template"
        proxy = "../../container-template/proxy"
    }
}
