variable "RELEASE" {
    default = "1.2.1"
}

target "default" {
    dockerfile = "Dockerfile"
    tags = ["yottalabs/oobabooga:${RELEASE}"]
    contexts = {
        scripts = "../../container-template"
        proxy = "../../container-template/proxy"
    }
}
