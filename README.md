# 📊 Stack de Monitoring Deployment System

## 🎯 Vue d'Ensemble

Stack complète de monitoring avec **Prometheus + Grafana + Loki + Alertmanager** pour surveiller le système de déploiement automatique. Cette solution monitoring surveille en temps réel :

- **🔌 Port Manager** (3005) - Allocation dynamique des ports  
- **🚀 Deployment API** (3004) - Orchestration des déploiements
- **🌩️ Tunnel Manager** (3001) - Gestion tunnels Cloudflare
- **🗄️ MongoDB** (27017) - Base de données
- **🐳 Docker Containers** (8100-8999) - Applications déployées
- **🖥️ Infrastructure** - Serveur Ubuntu (51.159.99.160)

## 🏗️ Architecture de Monitoring

```
┌─────────────────────────────────────────────────────────────────┐
│                    🌐 Cloudflare Tunnels                        │
├─────────────────────────────────────────────────────────────────┤
│  📈 Grafana (:3000)    📊 Prometheus (:9090)   🔔 Alerts (:9093)│
├─────────────────────────────────────────────────────────────────┤
│  📝 Loki (:3100)      🚛 Promtail            📊 Exporters       │
├─────────────────────────────────────────────────────────────────┤
│                  🐳 Docker Containers                           │
├─────────────────────────────────────────────────────────────────┤
│   🔌 Port Mgr  🚀 Deploy API  🌩️ Tunnel Mgr  🗄️ MongoDB       │
├─────────────────────────────────────────────────────────────────┤
│              🖥️ Ubuntu Server (51.159.99.160)                   │
└─────────────────────────────────────────────────────────────────┘
```

## 📋 Services Inclus

### Core Monitoring Stack

| Service | Port | Description | URL Tunnel |
|---------|------|-------------|------------|
| **Grafana** | 3000 | Dashboards et visualisation | `https://grafana.silverhawk77.click` |
| **Prometheus** | 9090 | Collecte et stockage métriques | `https://prometheus.silverhawk77.click` |
| **Alertmanager** | 9093 | Gestion des alertes | `https://alerts.silverhawk77.click` |
| **Loki** | 3100 | Agrégation des logs | (interne) |

### Data Collection

| Service | Port | Description |
|---------|------|-------------|
| **Node Exporter** | 9100 | Métriques système Ubuntu |
| **cAdvisor** | 8080 | Métriques containers Docker |
| **MongoDB Exporter** | 9216 | Métriques base de données |
| **Promtail** | 9080 | Collecteur de logs |

## 🚀 Déploiement Quick Start

### 1. Clonage et Configuration

```bash
# Clone du repository
git clone https://github.com/nekocheik/deployment-monitoring.git
cd deployment-monitoring

# Configuration des variables d'environnement
cp .env.example .env
# Éditer .env avec vos paramètres
```

### 2. Déploiement avec Docker Compose

```bash
# Démarrage de la stack complète
docker-compose up -d

# Vérification des services
docker-compose ps

# Suivre les logs
docker-compose logs -f grafana prometheus
```

### 3. Configuration Initiale

```bash
# Attendre que tous les services soient prêts (2-3 minutes)
./scripts/wait-for-services.sh

# Configuration initiale des dashboards
./scripts/setup-dashboards.sh

# Test des alertes
./scripts/test-alerts.sh
```

## 📊 Dashboards Grafana

### 🎯 Dashboard Principal - Deployment System
**URL:** `https://grafana.silverhawk77.click/d/deployment-main`

**Panels inclus:**
- **État des Services:** Status temps réel de tous les services critiques
- **Port Manager:** Métriques d'allocation des ports (8100-8999)
- **Deployment API:** Statistiques de déploiements (succès/échecs)  
- **Applications Déployées:** Liste et status des containers actifs
- **Performance:** Latence et temps de réponse
- **Erreurs:** Taux d'erreur et incidents

### 🏗️ Infrastructure Overview
**URL:** `https://grafana.silverhawk77.click/d/infrastructure-main`

**Métriques surveillées:**
- **CPU Usage:** Utilisation processeur par core
- **Memory Usage:** Consommation RAM avec swap
- **Disk Usage:** Espace disque par montage  
- **Network:** Trafic entrant/sortant
- **Load Average:** Charge système 1m/5m/15m
- **Container Stats:** Ressources utilisées par container

### 🌐 Applications Monitoring  
**URL:** `https://grafana.silverhawk77.click/d/applications-main`

**Application-specific metrics:**
- **HTTP Requests:** Volume et latence par app
- **Error Rates:** Taux d'erreur HTTP 4xx/5xx
- **Response Times:** Percentiles 50/95/99
- **Health Checks:** Status des endpoints /health
- **Container Resources:** CPU/RAM par application

## 🔔 Système d'Alertes

### Configuration Slack (Recommandée)

```bash
# Ajouter webhook Slack dans .env
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK

# Redémarrer Alertmanager
docker-compose restart alertmanager
```

### Types d'Alertes Configurées

#### 🚨 Alertes Critiques (Notification Immédiate)
- **Service Down:** Port Manager, Deployment API, Tunnel Manager indisponibles
- **MongoDB Down:** Base de données inaccessible  
- **Disk Space Critical:** < 10% d'espace disque libre
- **Memory Critical:** > 95% de RAM utilisée

#### ⚠️ Alertes Warning (5-10 min)
- **High Port Utilization:** > 80% des ports alloués
- **Deployment Failures:** > 2 échecs en 10 minutes  
- **High CPU:** > 80% pendant 5 minutes
- **Application Down:** Container non accessible
- **High Error Rate:** > 10% d'erreurs HTTP

#### 📊 Alertes Performance (15 min)
- **High Latency:** Temps déploiement > 10 minutes
- **MongoDB Slow:** Requêtes lentes détectées
- **Container Restart Loop:** Redémarrages fréquents

### Channels Slack Recommandés

```bash
#alerts-critical     # Alertes critiques uniquement
#deployment          # Notifications de déploiement  
#infrastructure      # Alertes serveur et ressources
#applications        # Status des apps déployées
```

## 📝 Logs et Debugging

### Recherche de Logs avec Loki

**Interface:** `https://grafana.silverhawk77.click/explore`

**Requêtes utiles:**

```logql
# Logs Port Manager dernière heure
{job="port-manager"} |= "ERROR" | json

# Déploiements avec erreurs
{job="deployment-api"} |= "❌" | json | deployment_id != ""

# Containers Docker qui redémarrent
{job="docker"} |= "restart" | json

# Erreurs système critiques  
{job="varlogs"} |= "ERROR" |= "CRITICAL" | logfmt

# Recherche par ID de déploiement
{job="deployment-api"} |= "deploy-1755768199487"
```

### Debug des Services

```bash
# Status détaillé de la stack
docker-compose ps
docker-compose logs --tail=50 prometheus grafana

# Vérification configuration Prometheus
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.health != "up")'

# Test des métriques services
curl -s http://51.159.99.160:3005/metrics | grep port_manager
curl -s http://51.159.99.160:3004/metrics | grep deployment

# Validation des alertes
curl -s http://localhost:9093/api/v1/alerts | jq '.data[] | select(.state == "firing")'
```

## ⚙️ Configuration Avancée

### Ajout de Nouvelles Métriques

**1. Port Manager - Métriques personnalisées:**

```javascript
// Dans port-manager.js - Ajouter endpoint /metrics
app.get('/metrics', (req, res) => {
  res.set('Content-Type', 'text/plain');
  res.send(`
# HELP port_manager_total_allocations Nombre total d'allocations
# TYPE port_manager_total_allocations gauge
port_manager_total_allocations ${Object.keys(portsDatabase.allocations).length}

# HELP port_manager_available_ports Ports disponibles
# TYPE port_manager_available_ports gauge  
port_manager_available_ports ${900 - Object.keys(portsDatabase.allocations).length}

# HELP port_manager_allocation_requests_total Total des demandes d'allocation
# TYPE port_manager_allocation_requests_total counter
port_manager_allocation_requests_total ${metricsCounters.allocationRequests}
  `);
});
```

**2. Deployment API - Métriques de déploiement:**

```javascript
// Dans deployment-api-enhanced.js - Endpoint métriques
app.get('/metrics', (req, res) => {
  res.set('Content-Type', 'text/plain');
  res.send(`
# HELP deployment_total Total déploiements
# TYPE deployment_total counter
deployment_total ${deploymentMetrics.total}

# HELP deployment_success_total Déploiements réussis
# TYPE deployment_success_total counter
deployment_success_total ${deploymentMetrics.success}

# HELP deployment_duration_seconds Durée des déploiements
# TYPE deployment_duration_seconds histogram
deployment_duration_seconds_bucket{le="60"} ${deploymentMetrics.buckets.under60}
deployment_duration_seconds_bucket{le="300"} ${deploymentMetrics.buckets.under300}
deployment_duration_seconds_bucket{le="+Inf"} ${deploymentMetrics.total}
  `);
});
```

### Scaling et Performance

**Prometheus - Configuration haute charge:**

```yaml
# Dans config/prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    replica: '1'

# Optimisation stockage
storage:
  tsdb:
    retention.time: 30d
    retention.size: 50GB
    wal-compression: true
```

**Grafana - Optimisation dashboards:**

```bash
# Variables d'environnement pour performance
GF_DATABASE_MAX_IDLE_CONN=25
GF_DATABASE_MAX_OPEN_CONN=100
GF_DATABASE_CONN_MAX_LIFETIME=14400
GF_RENDERING_SERVER_URL=http://renderer:8081/render
```

## 🔧 Maintenance et Backup

### Scripts de Maintenance

```bash
# Sauvegarde complète
./scripts/backup.sh

# Nettoyage logs anciens  
./scripts/cleanup-logs.sh

# Mise à jour des images
./scripts/update-images.sh

# Health check complet
./scripts/health-check.sh
```

### Sauvegarde Automatique

**Crontab recommandé:**

```bash
# Sauvegarde quotidienne à 2h00
0 2 * * * cd /home/ubuntu/deployment-monitoring && ./scripts/backup.sh

# Nettoyage hebdomadaire
0 3 * * 0 cd /home/ubuntu/deployment-monitoring && ./scripts/cleanup.sh

# Health check toutes les 4h
0 */4 * * * cd /home/ubuntu/deployment-monitoring && ./scripts/health-check.sh
```

## 📈 Métriques Clés à Surveiller

### 🎯 KPIs Business
- **Deployment Success Rate:** > 95% (objectif)
- **Average Deployment Time:** < 5 minutes
- **Port Utilization:** < 80% de la range
- **Application Uptime:** > 99.5%
- **MTTR (Mean Time To Recovery):** < 30 minutes

### 🖥️ KPIs Infrastructure  
- **CPU Utilization:** < 80% moyenne
- **Memory Usage:** < 85% avec buffer
- **Disk Usage:** < 80% avec alertes à 90%
- **Network Latency:** < 100ms p95
- **Container Restart Rate:** < 2 par jour

### 🔧 KPIs Opérationnels
- **Alert Response Time:** < 15 minutes
- **False Positive Rate:** < 5% des alertes
- **Monitoring Coverage:** 100% services critiques
- **Data Retention:** 30 jours métriques, 7 jours logs

## 🚀 Roadmap et Évolutions

### Phase 1 (Implémenté) ✅
- [x] Stack Prometheus + Grafana complète
- [x] Dashboards principaux deployment system  
- [x] Alertes critiques et infrastructure
- [x] Collection logs avec Loki + Promtail
- [x] Monitoring containers Docker

### Phase 2 (À venir)
- [ ] Service Discovery automatique des apps déployées
- [ ] Métriques business avancées (conversion, usage)
- [ ] Intégration APM (Application Performance Monitoring)
- [ ] Dashboards par équipe/projet
- [ ] Reporting automatique PDF/Email

### Phase 3 (Futur)
- [ ] Machine Learning pour détection d'anomalies
- [ ] Auto-scaling basé sur métriques
- [ ] Intégration avec outils externes (PagerDuty, Jira)
- [ ] Compliance et audit trail complet
- [ ] Multi-region monitoring

Cette stack de monitoring fournit une observabilité complète de votre système de déploiement automatique avec alertes proactives, dashboards intuitifs, et troubleshooting efficace ! 🎯