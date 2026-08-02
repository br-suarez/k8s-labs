output "service_name" {
  description = "Cluster-internal DNS name of the Service."
  value       = "${kubernetes_service_v1.this.metadata[0].name}.${var.namespace}.svc.cluster.local"
}

output "replicas" {
  description = "Replica count Terraform believes is desired."
  value       = kubernetes_deployment_v1.this.spec[0].replicas
}

output "config_map_name" {
  value = kubernetes_config_map_v1.this.metadata[0].name
}
