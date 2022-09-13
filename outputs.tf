output "dns_name" {
  description = "The public DNS name of the controller load balancer"
  value       = module.controllers.dns_name
}

output "s3command" {
  description = "The S3 cp command used to display the contents of the cloud-init-output.log"

  value = format(
    "aws s3 cp s3://%s/%s -",
    aws_s3_bucket.boundary.id,
    data.aws_s3_bucket_objects.cloudinit.keys[0]
  )
}

output "kms_key_alias_name" {
  value = aws_kms_alias.kms_key_alias.name
}


output "aws_kms_key" {
  value = aws_kms_key.key.id
}