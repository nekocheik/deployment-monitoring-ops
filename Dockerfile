# Multi-stage Dockerfile for Monitoring Stack
FROM node:18-alpine AS metrics-exporter

WORKDIR /app

# Create package.json for dependencies
RUN cat > package.json << 'EOF'
{
  "name": "deployment-metrics-exporter",
  "version": "1.0.0", 
  "type": "module",
  "dependencies": {
    "js-yaml": "^4.1.0"
  }
}
EOF

# Install dependencies
RUN npm install && apk add --no-cache curl

# Copy the metrics exporter script
COPY scripts/deployment-metrics-exporter.js ./metrics-exporter.js
COPY deployment.config.yaml ./deployment.config.yaml

EXPOSE 9091

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:9091/health || exit 1

# Start the exporter
CMD ["node", "metrics-exporter.js"]

# Production stage - Nginx to serve a simple monitoring dashboard
FROM nginx:alpine AS dashboard

# Copy a simple HTML dashboard
RUN cat > /usr/share/nginx/html/index.html << 'EOF'
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Monitoring Stack - Deployment System</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            margin: 0;
            padding: 20px;
            background: #f5f5f5;
            color: #333;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            padding: 30px;
        }
        h1 {
            color: #2c3e50;
            margin-bottom: 30px;
            text-align: center;
        }
        .services {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            margin-top: 30px;
        }
        .service {
            border: 1px solid #ddd;
            border-radius: 8px;
            padding: 20px;
            background: #f8f9fa;
        }
        .service h3 {
            margin-top: 0;
            color: #495057;
        }
        .service a {
            display: inline-block;
            background: #007bff;
            color: white;
            padding: 8px 16px;
            text-decoration: none;
            border-radius: 4px;
            margin-top: 10px;
        }
        .service a:hover {
            background: #0056b3;
        }
        .status {
            display: inline-block;
            padding: 4px 12px;
            border-radius: 20px;
            font-size: 14px;
            font-weight: bold;
        }
        .status.healthy {
            background: #d4edda;
            color: #155724;
        }
        .footer {
            text-align: center;
            margin-top: 40px;
            color: #666;
            font-size: 14px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Monitoring Stack - Deployment System</h1>
        
        <div class="services">
            <div class="service">
                <h3>📊 Grafana</h3>
                <p>Tableaux de bord et visualisation des métriques</p>
                <span class="status healthy">✅ Deployed</span>
                <br>
                <a href="/grafana" target="_blank">Accéder à Grafana</a>
            </div>
            
            <div class="service">
                <h3>📈 Prometheus</h3>
                <p>Collecte et stockage des métriques</p>
                <span class="status healthy">✅ Deployed</span>
                <br>
                <a href="/prometheus" target="_blank">Accéder à Prometheus</a>
            </div>
            
            <div class="service">
                <h3>🔔 Alertmanager</h3>
                <p>Gestion et routage des alertes</p>
                <span class="status healthy">✅ Deployed</span>
                <br>
                <a href="/alertmanager" target="_blank">Accéder à Alertmanager</a>
            </div>
            
            <div class="service">
                <h3>📊 Metrics Exporter</h3>
                <p>Métriques spécialisées pour les déploiements</p>
                <span class="status healthy">✅ Deployed</span>
                <br>
                <a href="/metrics" target="_blank">Voir les métriques</a>
            </div>
        </div>
        
        <div class="footer">
            <p>🤖 Déployé automatiquement via GitHub Actions</p>
            <p>Architecture: Cloud Deployment System</p>
        </div>
    </div>
</body>
</html>
EOF

# Configuration Nginx pour reverse proxy
RUN cat > /etc/nginx/conf.d/default.conf << 'EOF'
server {
    listen 80;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;
    
    # Dashboard principal
    location / {
        try_files $uri $uri/ /index.html;
    }
    
    # Health check
    location /health {
        access_log off;
        return 200 '{"status":"healthy","service":"monitoring-dashboard"}\n';
        add_header Content-Type application/json;
    }
    
    # Métriques (si l'exporter est accessible)
    location /metrics {
        proxy_pass http://localhost:9091/metrics;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
    
    # Redirection vers les services (si configurés via tunnels)
    location /grafana {
        return 302 https://grafana.silverhawk77.click;
    }
    
    location /prometheus {
        return 302 https://prometheus.silverhawk77.click;
    }
    
    location /alertmanager {
        return 302 https://alerts.silverhawk77.click;
    }
}
EOF

EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:80/health || exit 1

CMD ["nginx", "-g", "daemon off;"]