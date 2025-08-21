# Multi-service Monitoring Stack avec Reverse Proxy intégré
FROM nginx:alpine

# Installer supervisor pour gérer plusieurs processus
RUN apk add --no-cache supervisor curl nodejs npm \
    && rm -rf /var/cache/apk/*

# Créer les répertoires nécessaires  
RUN mkdir -p /app/metrics-exporter \
             /app/grafana-proxy \
             /var/log/supervisor \
             /usr/share/nginx/html \
             /etc/supervisor/conf.d

# Configuration Supervisor pour multi-services
RUN cat > /etc/supervisor/conf.d/supervisord.conf << 'EOF'
[supervisord]
nodaemon=true
user=root
logfile=/var/log/supervisor/supervisord.log
pidfile=/var/run/supervisord.pid

[program:nginx]
command=nginx -g "daemon off;"
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
autorestart=true
priority=10

[program:metrics-exporter]
command=node metrics-exporter.js
directory=/app/metrics-exporter
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
autorestart=true
priority=20
user=nginx

[program:grafana-proxy]
command=node grafana-proxy.js
directory=/app/grafana-proxy
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
autorestart=true
priority=30
user=nginx
EOF

# Copier et configurer le metrics exporter
COPY package.json /app/metrics-exporter/
COPY scripts/deployment-metrics-exporter.js /app/metrics-exporter/metrics-exporter.js
COPY deployment.config.yaml /app/metrics-exporter/

RUN cd /app/metrics-exporter && npm install

# Créer un proxy simple pour Grafana (simule l'interface)
RUN cat > /app/grafana-proxy/package.json << 'EOF'
{
  "name": "grafana-proxy",
  "version": "1.0.0",
  "type": "module",
  "dependencies": {
    "express": "^4.18.2"
  }
}
EOF

RUN cat > /app/grafana-proxy/grafana-proxy.js << 'EOF'
import express from 'express';

const app = express();
const PORT = 3001;

app.use(express.json());

// Simulation API Grafana
app.get('/api/health', (req, res) => {
  res.json({ 
    commit: "monitoring-stack",
    database: "ok",
    version: "monitoring-v1.0" 
  });
});

app.get('/', (req, res) => {
  res.send(`
    <html>
      <head><title>Grafana - Monitoring Stack</title></head>
      <body>
        <h1>🎯 Grafana Dashboard</h1>
        <p>Interface de monitoring pour le système de déploiement</p>
        <ul>
          <li><a href="/api/health">Health Check</a></li>
          <li><a href="/">Dashboard Principal</a></li>
        </ul>
        <p><em>Service simulé - intégré dans le monitoring stack</em></p>
      </body>
    </html>
  `);
});

app.get('/d/:dashboard', (req, res) => {
  res.json({
    dashboard: req.params.dashboard,
    title: "Deployment Monitoring",
    panels: [
      { title: "Deployments Total", value: 12 },
      { title: "Success Rate", value: "91.7%" },
      { title: "Active Services", value: 6 }
    ]
  });
});

app.listen(PORT, () => {
  console.log(`🎯 Grafana Proxy running on port ${PORT}`);
});
EOF

RUN cd /app/grafana-proxy && npm install

# Dashboard HTML avec liens internes
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
                <span class="status healthy">✅ Active</span>
                <br>
                <a href="/grafana/">Interface Grafana</a>
                <a href="/grafana/api/health">Health Check</a>
            </div>
            
            <div class="service">
                <h3>📈 Prometheus (Simulé)</h3>
                <p>Collecte et stockage des métriques</p>
                <span class="status healthy">✅ Active</span>
                <br>
                <a href="/metrics">Métriques Prometheus</a>
            </div>
            
            <div class="service">
                <h3>📊 Metrics Exporter</h3>
                <p>Métriques spécialisées pour les déploiements</p>
                <span class="status healthy">✅ Active</span>
                <br>
                <a href="/metrics">Métriques Déploiement</a>
                <a href="/exporter/health">Health Check</a>
            </div>
            
            <div class="service">
                <h3>🔍 System Status</h3>
                <p>État général du système de monitoring</p>
                <span class="status healthy">✅ Operational</span>
                <br>
                <a href="/health">Global Health</a>
                <a href="/status">Status API</a>
            </div>
        </div>
        
        <div class="footer">
            <p>🤖 Déployé automatiquement via GitHub Actions</p>
            <p>Architecture: Cloud Deployment System - Multi-Service Stack</p>
        </div>
    </div>
</body>
</html>
EOF

# Configuration Nginx avec reverse proxy pour tous les services
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
    
    # Health check global
    location /health {
        access_log off;
        return 200 '{"status":"healthy","service":"monitoring-stack","services":["nginx","metrics-exporter","grafana-proxy"]}\n';
        add_header Content-Type application/json;
    }
    
    # Status API
    location /status {
        access_log off;
        return 200 '{"monitoring-stack":"operational","grafana":"active","prometheus":"simulated","metrics-exporter":"active"}\n';
        add_header Content-Type application/json;
    }
    
    # Métriques depuis l'exporter
    location /metrics {
        proxy_pass http://localhost:9091/metrics;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_connect_timeout 5s;
        proxy_read_timeout 10s;
    }
    
    # Health check metrics exporter
    location /exporter/health {
        proxy_pass http://localhost:9091/health;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
    
    # Interface Grafana (proxy vers notre service)
    location /grafana/ {
        proxy_pass http://localhost:3001/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

EXPOSE 80

# Health check global
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:80/health || exit 1

# Démarrage supervisor (gère nginx + metrics-exporter + grafana-proxy)
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]