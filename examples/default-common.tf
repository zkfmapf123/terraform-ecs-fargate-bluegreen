provider "aws" {
  region = "ap-northeast-2"
}

module "default-common" {

  source = "../"

}