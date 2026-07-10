pid_file = "/tmp/identity-agent.pid"

vault {
  address = "https://vault:8200"
  ca_cert = "/vault/tls/vault.crt"
}

auto_auth {
  method "token_file" {
    config = {
      token_file_path = "/vault/config/agent-token"
    }
  }
}

template {
  contents = <<EOH
{{ with secret "pki/issue/microservices" "common_name=identity.service.local" "ttl=24h" }}
{{ .Data.certificate }}
{{ .Data.private_key }}
{{ end }}
EOH

  destination = "/vault/rendered/server.pem"
}

template {
  contents = <<EOH
{{ with secret "pki/cert/ca" }}
{{ .Data.certificate }}
{{ end }}
EOH

  destination = "/vault/rendered/ca.crt"
}

template {
  contents = <<EOH
{{ with secret "hactt-secret/data/hactt-identity/config" }}
{{ range $k, $v := .Data.data }}
{{ $k }}={{ $v }}
{{ end }}
{{ end }}
EOH

  destination = "/vault/secret/identity-secrets.properties"
}