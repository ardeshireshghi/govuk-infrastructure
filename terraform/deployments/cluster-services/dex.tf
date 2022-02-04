# Installs and configures Dex, a federated OpenID Connect provider

locals {
  dex_host = "dex.${local.external_dns_zone_name}"
}

resource "helm_release" "dex" {
  chart      = "dex"
  name       = "dex"
  namespace  = local.services_ns
  repository = "https://charts.dexidp.io"
  version    = "0.6.5" # TODO: Dependabot or equivalent so this doesn't get neglected.
  values = [yamlencode({
    config = {
      issuer = "https://${local.dex_host}"

      storage = {
        type = "kubernetes"
        config = {
          inCluster = true
        }
      }

      connectors = [
        {
          type = "github"
          id   = "github"
          name = "GitHub"
          config = {
            clientID      = "$GITHUB_CLIENT_ID"
            clientSecret  = "$GITHUB_CLIENT_SECRET"
            redirectURI   = "https://${local.dex_host}/callback"
            orgs          = var.dex_github_orgs_teams
            teamNameField = "both"
            useLoginAsID  = true
          }
        }
      ]

      # staticClients uses a different method for expansion of environment
      # variables, see [bug](https://github.com/gabibbo97/charts/issues/36#issuecomment-736911424)
      staticClients = [
        {
          name         = "argo-workflows"
          idEnv        = "ARGO_WORKFLOWS_CLIENT_ID"
          secretEnv    = "ARGO_WORKFLOWS_CLIENT_SECRET"
          redirectURIs = ["https://${local.argo_workflows_host}/oauth2/callback"]
        },
        {
          name         = "argocd"
          idEnv        = "ARGOCD_CLIENT_ID"
          secretEnv    = "ARGOCD_CLIENT_SECRET"
          redirectURIs = ["https://${local.argo_host}/auth/callback"]
        },
        {
          name         = "grafana"
          idEnv        = "GRAFANA_CLIENT_ID"
          secretEnv    = "GRAFANA_CLIENT_SECRET"
          redirectURIs = ["https://${local.grafana_host}/login/generic_oauth"]
        }
      ]
    }

    envVars = [
      {
        name = "GITHUB_CLIENT_ID"
        valueFrom = {
          secretKeyRef = {
            name = "govuk-dex-github"
            key  = "GITHUB_CLIENT_ID"
          }
        }
      },
      {
        name = "GITHUB_CLIENT_SECRET"
        valueFrom = {
          secretKeyRef = {
            name = "govuk-dex-github"
            key  = "GITHUB_CLIENT_SECRET"
          }
        }
      },
      {
        name = "ARGO_WORKFLOWS_CLIENT_ID"
        valueFrom = {
          secretKeyRef = {
            name = "govuk-dex-argo-workflows"
            key  = "ARGO_WORKFLOWS_CLIENT_ID"
          }
        }
      },
      {
        name = "ARGO_WORKFLOWS_CLIENT_SECRET"
        valueFrom = {
          secretKeyRef = {
            name = "govuk-dex-argo-workflows"
            key  = "ARGO_WORKFLOWS_CLIENT_SECRET"
          }
        }
      },
      {
        name = "ARGOCD_CLIENT_ID"
        valueFrom = {
          secretKeyRef = {
            name = "govuk-dex-argocd"
            key  = "ARGOCD_CLIENT_ID"
          }
        }
      },
      {
        name = "ARGOCD_CLIENT_SECRET"
        valueFrom = {
          secretKeyRef = {
            name = "govuk-dex-argocd"
            key  = "ARGOCD_CLIENT_SECRET"
          }
        }
      },
      {
        name = "GRAFANA_CLIENT_ID"
        valueFrom = {
          secretKeyRef = {
            name = "govuk-dex-grafana"
            key  = "GRAFANA_CLIENT_ID"
          }
        }
      },
      {
        name = "GRAFANA_CLIENT_SECRET"
        valueFrom = {
          secretKeyRef = {
            name = "govuk-dex-grafana"
            key  = "GRAFANA_CLIENT_SECRET"
          }
        }
      }
    ]

    service = {
      ports = {
        http = {
          port = 80
        }
        https = {
          port = 443
        }
      }
    }

    ingress = {
      enabled = true
      annotations = {
        "alb.ingress.kubernetes.io/group.name"         = "dex"
        "alb.ingress.kubernetes.io/scheme"             = "internet-facing"
        "alb.ingress.kubernetes.io/target-type"        = "ip"
        "alb.ingress.kubernetes.io/load-balancer-name" = "dex"
        "alb.ingress.kubernetes.io/listen-ports"       = jsonencode([{ "HTTP" : 80 }, { "HTTPS" : 443 }])
        "alb.ingress.kubernetes.io/ssl-redirect"       = "443"
      }
      className = "aws-alb"
      hosts = [
        {
          host = local.dex_host
          paths = [
            {
              path     = "/*"
              pathType = "ImplementationSpecific"
            }
          ]
        }
      ]
    }
  })]
}
