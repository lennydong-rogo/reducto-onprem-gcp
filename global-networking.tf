# Gateway API resources for global access
# When enable_global_access is true, we use Gateway API instead of Ingress
# because internal Application Load Balancers via Ingress don't support global access

resource "kubectl_manifest" "gateway" {
  count = var.enable_global_access ? 1 : 0

  yaml_body = <<-EOT
    apiVersion: gateway.networking.k8s.io/v1
    kind: Gateway
    metadata:
      name: reducto-gateway
      namespace: ${kubectl_manifest.namespace.name}
    spec:
      gatewayClassName: gke-l7-rilb
      listeners:
      - name: http
        protocol: HTTP
        port: 80
    EOT

  depends_on = [module.gke, kubectl_manifest.namespace]
}

resource "kubectl_manifest" "gateway_policy" {
  count = var.enable_global_access ? 1 : 0

  yaml_body = <<-EOT
    apiVersion: networking.gke.io/v1
    kind: GCPGatewayPolicy
    metadata:
      name: reducto-gateway-policy
      namespace: ${kubectl_manifest.namespace.name}
    spec:
      default:
        allowGlobalAccess: true
      targetRef:
        group: gateway.networking.k8s.io
        kind: Gateway
        name: reducto-gateway
    EOT

  depends_on = [kubectl_manifest.gateway]
}

resource "kubectl_manifest" "http_route" {
  count = var.enable_global_access ? 1 : 0

  yaml_body = <<-EOT
    apiVersion: gateway.networking.k8s.io/v1
    kind: HTTPRoute
    metadata:
      name: reducto-route
      namespace: ${kubectl_manifest.namespace.name}
    spec:
      parentRefs:
      - kind: Gateway
        name: reducto-gateway
      rules:
      - backendRefs:
        - name: reducto-reducto-http
          port: 80
    EOT

  depends_on = [kubectl_manifest.gateway, helm_release.reducto]
}

# GCPBackendPolicy replaces BackendConfig when using Gateway API
# Configures timeout and connection draining for the backend service
resource "kubectl_manifest" "backend_policy" {
  count = var.enable_global_access ? 1 : 0

  yaml_body = <<-EOT
    apiVersion: networking.gke.io/v1
    kind: GCPBackendPolicy
    metadata:
      name: reducto-backend-policy
      namespace: ${kubectl_manifest.namespace.name}
    spec:
      default:
        timeoutSec: 900
        connectionDraining:
          drainingTimeoutSec: 300
      targetRef:
        group: ""
        kind: Service
        name: reducto-reducto-http
    EOT

  depends_on = [helm_release.reducto]
}