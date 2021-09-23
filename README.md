# TLS certificate using Let's Encrypt, Istio, cert-manager, and ngrok

This is an example repository that runs a ngrok process serving HTTP and HTTPS on the same host, handle requests HTTP/HTTPS with Istio, issues TLS certificates using cert-manager via Let's Encrypt. HTTP-to-HTTPS redirect is (somewhat) enabled.

## Prerequisites

* kubectl
* k3d
* helm
  * kubed
  * cert-manager

## Usage

1. Create `ngrok-auth-token` file containing your Ngrok token in the root of this repository
2. Run `$ ./start.sh`, which creates `istio-acme` cluster on k3d

## ngrok

### DNS set up

1. To use TLS, ngrok requires the Pro or Business plan.
2. Add a custom domain name that you want to use on the ngrok Dashboard. Then,
   copy its hostname assigned for a CNAME record (`*.cname.<region>.ngrok.io`).
3. Create a CNAME record for the previous hostname.

### Configuration

```yaml
tunnels:
  <some name for http>:
    proto: http
    addr: istio-ingressgateway.istio-system.svc:80
    host_header: preserve
    bind_tls: false
    # A wildcard host name is only available for the Business plan
    hostname: <hostname registered on the ngrok Dashboard>
  <some name for https>:
    proto: tls
    addr: istio-ingressgateway.istio-system.svc:443
    hostname: <hostname registered on the ngrok Dashboard>
```

`http` is used for ACME.

## cert-manager

### Kubernetes Gateway API

cert-manager supports [Kubernetes Gateway API](https://cert-manager.io/docs/configuration/acme/http01/#configuring-the-http-01-gateway-api-solver). `extraArgs` must contain `--feature-gates=ExperimentalGatewayAPISupport=true`.

At the time of writing, `Gateway` needs to be in the same namespace as `istio-ingressgateway`. `HTTPRoute` can be in different namespaces, and multiple `HTTPRoute` can be provided for the same listener.

### Certificate

A certificate can be created in a different namespace than Istio, but the TLS secret needs to be copied to the Istio's namespace in that case because the `istio-ingressgateway` needs to mount it.

### HTTP-to-HTTPS redirect

`gateway` in this repo has two `HTTPRoute`. One is `http-to-https-redirect` which performs HTTPS redirect on HTTP endpoints other than ones starting with `.`. The other one is created by cert-manager while ACME HTTP solver is required. The path starts with `/.well-known/` and it's excluded from the first `HTTPRoute`. I couldn't think of a better approach to do this more precisely.

When two `HTTPRoute`s for the same host exist on the same gateway, it seems like the one created first will be matched first at least with Istio (at the time of writing). So, when the `HTTPRoute` for redirection has a catch-all route, the one created by cert-manager will not be used. As a result, ACME challenge will fail until the first `HTTPRoute` is removed.

### Note

cert-manager currently disables Istio sidecar in the ACME HTTP solver pod by a hard coded annotation.

## Istio

Just mount the TLS certificate created by cert-manager.

Istio's Gateway and Kubernetes' Gateway can be used together.
