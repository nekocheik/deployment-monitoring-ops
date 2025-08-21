#!/bin/bash

# 📊 Script d'installation du stack de monitoring pour le système de déploiement

set -e  # Exit on any error

echo "🚀 Installation du Stack de Monitoring Deployment System"
echo "=========================================================="

# Vérification des prérequis
echo "🔍 Vérification des prérequis..."

if ! command -v docker &> /dev/null; then
    echo "❌ Docker n'est pas installé"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose n'est pas installé"
    exit 1
fi

echo "✅ Docker et Docker Compose sont installés"

# Vérification de la connexion aux services
echo "🔍 Vérification de la connectivité aux services..."

SERVICES_TO_CHECK=(
    "51.159.99.160:3004:Deployment API"
    "51.159.99.160:3005:Port Manager"
    "51.159.99.160:3001:Tunnel Manager"
)

for service in "${SERVICES_TO_CHECK[@]}"; do
    IFS=':' read -r ip port name <<< "$service"
    if timeout 5 bash -c "</dev/tcp/$ip/$port" &>/dev/null; then
        echo "✅ $name ($ip:$port) accessible"
    else
        echo "⚠️ $name ($ip:$port) non accessible - monitoring limité"
    fi
done

# Création des répertoires nécessaires
echo "📁 Création des répertoires de données..."
mkdir -p data/{prometheus,grafana,loki,alertmanager}
sudo chown -R 472:472 data/grafana  # UID Grafana
sudo chown -R 65534:65534 data/prometheus data/alertmanager  # UID nobody

# Configuration de l'environnement
echo "⚙️ Configuration de l'environnement..."
if [ ! -f .env ]; then
    cp .env.example .env
    echo "📝 Fichier .env créé. Vous pouvez le personnaliser selon vos besoins."
else
    echo "✅ Fichier .env existant conservé"
fi

# Build des images personnalisées
echo "🏗️ Build de l'image Deployment Metrics Exporter..."
docker build -f Dockerfile.metrics-exporter -t deployment-metrics-exporter:latest .

# Vérification de l'espace disque
echo "💾 Vérification de l'espace disque disponible..."
AVAILABLE_SPACE=$(df / | tail -1 | awk '{print $4}')
REQUIRED_SPACE=2097152  # 2GB en KB

if [ "$AVAILABLE_SPACE" -lt "$REQUIRED_SPACE" ]; then
    echo "⚠️ Attention: Espace disque faible (< 2GB). Le monitoring peut être impacté."
else
    echo "✅ Espace disque suffisant"
fi

# Démarrage des services
echo "🚀 Démarrage du stack de monitoring..."
docker-compose up -d

# Attendre que les services soient prêts
echo "⏳ Attente du démarrage des services (60 secondes)..."
sleep 60

# Vérification du démarrage
echo "🔍 Vérification du statut des services..."
MONITORING_SERVICES=(
    "localhost:3000:Grafana"
    "localhost:9090:Prometheus" 
    "localhost:9093:Alertmanager"
    "localhost:9091:Deployment Metrics Exporter"
)

ALL_SERVICES_OK=true

for service in "${MONITORING_SERVICES[@]}"; do
    IFS=':' read -r host port name <<< "$service"
    if curl -f -s -o /dev/null --connect-timeout 10 "http://$host:$port"; then
        echo "✅ $name accessible sur http://$host:$port"
    else
        echo "❌ $name non accessible sur http://$host:$port"
        ALL_SERVICES_OK=false
    fi
done

# Configuration initiale Grafana
echo "⚙️ Configuration initiale de Grafana..."
sleep 10  # Laisser un peu plus de temps à Grafana

# Vérifier si Grafana est accessible
if curl -f -s -o /dev/null "http://localhost:3000"; then
    echo "✅ Grafana accessible"
    echo "🔑 Identifiants par défaut: admin / monitoring2024!"
    echo "🌐 Interface: http://localhost:3000"
else
    echo "⚠️ Grafana non accessible - vérifiez les logs: docker-compose logs grafana"
fi

# Résumé de l'installation
echo ""
echo "🎉 Installation terminée!"
echo "======================="
echo ""
echo "📊 Services de monitoring disponibles:"
echo "  • Grafana (Dashboards):        http://localhost:3000"
echo "  • Prometheus (Métriques):      http://localhost:9090"  
echo "  • Alertmanager (Alertes):      http://localhost:9093"
echo "  • Metrics Exporter:            http://localhost:9091"
echo ""
echo "🔑 Identifiants Grafana:"
echo "  • Utilisateur: admin"
echo "  • Mot de passe: monitoring2024!"
echo ""
echo "🌐 Si configuré avec Cloudflare Tunnels:"
echo "  • Grafana:      https://grafana.silverhawk77.click"
echo "  • Prometheus:   https://prometheus.silverhawk77.click"
echo "  • Alertmanager: https://alerts.silverhawk77.click"
echo ""
echo "📋 Commandes utiles:"
echo "  • Voir les logs:     docker-compose logs -f"
echo "  • Arrêter:          docker-compose down"
echo "  • Redémarrer:       docker-compose restart"
echo "  • Mise à jour:      docker-compose pull && docker-compose up -d"
echo ""

if [ "$ALL_SERVICES_OK" = false ]; then
    echo "⚠️ Certains services ne sont pas accessibles."
    echo "   Vérifiez les logs avec: docker-compose logs [nom-service]"
    echo "   Services disponibles: grafana, prometheus, alertmanager, loki, node-exporter"
    exit 1
else
    echo "✅ Tous les services de monitoring sont opérationnels!"
    echo ""
    echo "🎯 Étapes suivantes recommandées:"
    echo "  1. Configurer les notifications Slack dans .env si souhaité"
    echo "  2. Personnaliser les dashboards Grafana selon vos besoins"  
    echo "  3. Configurer les tunnels Cloudflare pour l'accès externe"
    echo "  4. Mettre en place la sauvegarde automatique des données"
fi

echo ""
echo "📚 Documentation complète disponible dans README.md"