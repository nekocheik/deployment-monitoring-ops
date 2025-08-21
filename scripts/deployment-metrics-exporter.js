#!/usr/bin/env node

/**
 * 📊 Deployment Metrics Exporter
 * Exporte les métriques spécialisées pour le monitoring des déploiements basés sur la structure starter-frontend
 */

import { readFileSync, existsSync } from 'fs';
import { join } from 'path';
import yaml from 'js-yaml';
import { createServer } from 'http';

// Configuration
const PORT = process.env.METRICS_EXPORTER_PORT || 9091;
const DEPLOYMENT_API_URL = process.env.DEPLOYMENT_API_URL || 'http://51.159.99.160:3004';
const PORT_MANAGER_URL = process.env.PORT_MANAGER_URL || 'http://51.159.99.160:3005';

// État des métriques
let metrics = {
  deployments: {
    total: 0,
    success: 0,
    failed: 0,
    in_progress: 0,
    by_project: {},
    by_branch: {},
    github_actions_triggered: 0,
    webhook_received: 0
  },
  applications: {
    active: 0,
    by_template: {},
    by_framework: {},
    health_checks: {
      passing: 0,
      failing: 0,
      total: 0
    }
  },
  infrastructure: {
    ports_allocated: 0,
    ports_available: 0,
    containers_running: 0,
    docker_images: 0
  },
  github_actions: {
    workflows_triggered: 0,
    jobs_completed: 0,
    jobs_failed: 0,
    average_duration: 0,
    ci_cd_pipeline_success_rate: 0
  }
};

// Fonction pour récupérer les métriques du Port Manager
async function fetchPortManagerMetrics() {
  try {
    const response = await fetch(`${PORT_MANAGER_URL}/status`);
    const data = await response.json();
    
    metrics.infrastructure.ports_allocated = data.totalAllocations || 0;
    metrics.infrastructure.ports_available = data.availablePorts || 0;
    
    // Analyser les allocations par projet/branche
    if (data.database && data.database.allocations) {
      const allocations = data.database.allocations;
      Object.keys(allocations).forEach(key => {
        const allocation = allocations[key];
        const project = allocation.project;
        const branch = allocation.branch;
        
        if (!metrics.deployments.by_project[project]) {
          metrics.deployments.by_project[project] = 0;
        }
        if (!metrics.deployments.by_branch[branch]) {
          metrics.deployments.by_branch[branch] = 0;
        }
        
        metrics.deployments.by_project[project]++;
        metrics.deployments.by_branch[branch]++;
      });
    }
  } catch (error) {
    console.error('Erreur lors de la récupération des métriques Port Manager:', error);
  }
}

// Fonction pour récupérer les métriques du Deployment API
async function fetchDeploymentAPIMetrics() {
  try {
    const response = await fetch(`${DEPLOYMENT_API_URL}/status`);
    const data = await response.json();
    
    metrics.deployments.total = data.totalDeployments || 0;
    metrics.deployments.success = data.successfulDeployments || 0;
    metrics.deployments.failed = data.failedDeployments || 0;
    
    if (data.status === 'deploying') {
      metrics.deployments.in_progress = 1;
    } else {
      metrics.deployments.in_progress = 0;
    }
    
    // Récupérer les logs récents pour analyser les patterns
    const logsResponse = await fetch(`${DEPLOYMENT_API_URL}/logs`);
    const logsData = await logsResponse.json();
    
    if (logsData.logs) {
      // Analyser les logs pour extraire des métriques
      logsData.logs.forEach(log => {
        if (log.message && log.message.includes('GitHub Actions')) {
          metrics.github_actions.workflows_triggered++;
        }
        if (log.message && log.message.includes('webhook')) {
          metrics.deployments.webhook_received++;
        }
      });
    }
  } catch (error) {
    console.error('Erreur lors de la récupération des métriques Deployment API:', error);
  }
}

// Fonction pour analyser les applications déployées
async function analyzeDeployedApplications() {
  const portRange = Array.from({length: 20}, (_, i) => 8100 + i);
  let activeApps = 0;
  let healthyApps = 0;
  let unhealthyApps = 0;
  
  for (const port of portRange) {
    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 5000);
      
      const response = await fetch(`http://51.159.99.160:${port}/health`, {
        signal: controller.signal,
        method: 'GET',
        timeout: 5000
      });
      
      clearTimeout(timeoutId);
      
      if (response.ok) {
        activeApps++;
        healthyApps++;
        
        // Tenter de déterminer le type d'application
        const userAgent = response.headers.get('server');
        if (userAgent && userAgent.includes('nginx')) {
          if (!metrics.applications.by_framework['vite-react']) {
            metrics.applications.by_framework['vite-react'] = 0;
          }
          metrics.applications.by_framework['vite-react']++;
          
          if (!metrics.applications.by_template['starter-frontend']) {
            metrics.applications.by_template['starter-frontend'] = 0;
          }
          metrics.applications.by_template['starter-frontend']++;
        }
      }
    } catch (error) {
      if (activeApps > 0 || error.code !== 'ECONNREFUSED') {
        unhealthyApps++;
      }
    }
  }
  
  metrics.applications.active = activeApps;
  metrics.applications.health_checks.passing = healthyApps;
  metrics.applications.health_checks.failing = unhealthyApps;
  metrics.applications.health_checks.total = healthyApps + unhealthyApps;
}

// Fonction pour analyser les deployment.config.yaml des projets
async function analyzeDeploymentConfigs() {
  const configFiles = [
    './deployment.config.yaml',  // Config du monitoring lui-même
    '../starter-frontend/deployment.config.yaml'  // Config starter-frontend
  ];
  
  for (const configFile of configFiles) {
    try {
      if (existsSync(configFile)) {
        const configContent = readFileSync(configFile, 'utf8');
        const config = yaml.load(configContent);
        
        // Analyser la configuration du monitoring
        if (configFile.includes('deployment-monitoring')) {
          if (config.deployment?.monitoring?.enabled) {
            metrics.applications.by_template['monitoring-stack'] = 1;
          }
          
          // Compter les services du stack
          if (config.deployment?.docker?.services) {
            metrics.infrastructure.monitoring_services = config.deployment.docker.services.length;
          }
          
          // Analyser les targets configurés
          if (config.deployment?.targets?.core_services) {
            metrics.deployments.monitored_services = config.deployment.targets.core_services.length;
          }
        }
        
        // Analyser la configuration starter-frontend
        if (configFile.includes('starter-frontend')) {
          const projectName = config.project?.name || 'unknown';
          
          if (!metrics.deployments.by_project[projectName]) {
            metrics.deployments.by_project[projectName] = 0;
          }
          
          // Analyser les environnements auto-deploy
          if (config.deployment?.environments) {
            Object.entries(config.deployment.environments).forEach(([env, envConfig]) => {
              if (envConfig.auto_deploy) {
                if (!metrics.deployments.by_branch[env]) {
                  metrics.deployments.by_branch[env] = 0;
                }
                metrics.deployments.by_branch[env]++;
              }
            });
          }
          
          // Vérifier le monitoring
          if (config.deployment?.monitoring?.enabled) {
            metrics.applications.by_template['starter-frontend-monitored'] = 1;
          }
          
          // Analyser les ports configurés
          if (config.deployment?.ports?.allocated) {
            metrics.applications.configured_ports = (metrics.applications.configured_ports || 0) + 1;
          }
        }
        
        console.log(`✅ Configuration analysée: ${configFile.split('/').pop()}`);
      }
    } catch (error) {
      console.error(`⚠️ Erreur analyse config ${configFile}:`, error.message);
    }
  }
}

// Fonction pour récupérer les métriques Docker
async function fetchDockerMetrics() {
  try {
    // Cette fonction nécessiterait l'accès à l'API Docker
    // Pour l'instant, on estime basé sur les applications actives
    metrics.infrastructure.containers_running = metrics.applications.active;
    
    // Estimation du nombre d'images (base + apps déployées)
    metrics.infrastructure.docker_images = 5 + metrics.applications.active;
  } catch (error) {
    console.error('Erreur lors de la récupération des métriques Docker:', error);
  }
}

// Calculer les métriques dérivées
function calculateDerivedMetrics() {
  // Taux de succès des déploiements
  if (metrics.deployments.total > 0) {
    const successRate = (metrics.deployments.success / metrics.deployments.total) * 100;
    metrics.github_actions.ci_cd_pipeline_success_rate = Math.round(successRate * 100) / 100;
  }
  
  // Estimation de la durée moyenne des déploiements (basée sur les logs)
  // Pour l'instant, on utilise une estimation
  metrics.github_actions.average_duration = 180; // 3 minutes en secondes
}

// Générer les métriques au format Prometheus
function generatePrometheusMetrics() {
  const timestamp = Date.now();
  
  let result = `# HELP deployment_total Nombre total de déploiements
# TYPE deployment_total counter
deployment_total ${metrics.deployments.total} ${timestamp}

# HELP deployment_success_total Déploiements réussis
# TYPE deployment_success_total counter  
deployment_success_total ${metrics.deployments.success} ${timestamp}

# HELP deployment_failed_total Déploiements échoués
# TYPE deployment_failed_total counter
deployment_failed_total ${metrics.deployments.failed} ${timestamp}

# HELP deployment_in_progress Déploiements en cours
# TYPE deployment_in_progress gauge
deployment_in_progress ${metrics.deployments.in_progress} ${timestamp}

# HELP github_actions_workflows_total Workflows GitHub Actions déclenchés
# TYPE github_actions_workflows_total counter
github_actions_workflows_total ${metrics.github_actions.workflows_triggered} ${timestamp}

# HELP github_actions_success_rate Taux de succès CI/CD
# TYPE github_actions_success_rate gauge
github_actions_success_rate ${metrics.github_actions.ci_cd_pipeline_success_rate} ${timestamp}

# HELP deployment_webhook_received_total Webhooks reçus
# TYPE deployment_webhook_received_total counter
deployment_webhook_received_total ${metrics.deployments.webhook_received} ${timestamp}

# HELP applications_active Applications actives
# TYPE applications_active gauge
applications_active ${metrics.applications.active} ${timestamp}

# HELP applications_health_checks_passing Health checks réussis
# TYPE applications_health_checks_passing gauge
applications_health_checks_passing ${metrics.applications.health_checks.passing} ${timestamp}

# HELP applications_health_checks_failing Health checks échoués
# TYPE applications_health_checks_failing gauge
applications_health_checks_failing ${metrics.applications.health_checks.failing} ${timestamp}

# HELP port_manager_ports_allocated Ports alloués
# TYPE port_manager_ports_allocated gauge
port_manager_ports_allocated ${metrics.infrastructure.ports_allocated} ${timestamp}

# HELP port_manager_ports_available Ports disponibles
# TYPE port_manager_ports_available gauge
port_manager_ports_available ${metrics.infrastructure.ports_available} ${timestamp}

# HELP docker_containers_running Conteneurs Docker en cours
# TYPE docker_containers_running gauge
docker_containers_running ${metrics.infrastructure.containers_running} ${timestamp}

# HELP starter_frontend_applications Applications basées sur starter-frontend
# TYPE starter_frontend_applications gauge
starter_frontend_applications ${metrics.applications.by_template['starter-frontend'] || 0} ${timestamp}

# HELP vite_react_applications Applications Vite + React
# TYPE vite_react_applications gauge  
vite_react_applications ${metrics.applications.by_framework['vite-react'] || 0} ${timestamp}

# HELP deployment_config_analysis Analyse des fichiers deployment.config.yaml
# TYPE deployment_config_analysis gauge
deployment_config_monitoring_stack ${metrics.applications.by_template['monitoring-stack'] || 0} ${timestamp}
deployment_config_starter_frontend_monitored ${metrics.applications.by_template['starter-frontend-monitored'] || 0} ${timestamp}
deployment_config_configured_ports ${metrics.applications.configured_ports || 0} ${timestamp}

# HELP monitoring_services_configured Services de monitoring configurés
# TYPE monitoring_services_configured gauge  
monitoring_services_configured ${metrics.infrastructure.monitoring_services || 0} ${timestamp}

# HELP monitored_services_total Services surveillés
# TYPE monitored_services_total gauge
monitored_services_total ${metrics.deployments.monitored_services || 0} ${timestamp}
`;

  // Ajouter des métriques par projet si disponibles
  Object.entries(metrics.deployments.by_project).forEach(([project, count]) => {
    result += `# HELP deployment_by_project_${project.replace(/[^a-zA-Z0-9]/g, '_')} Déploiements par projet
# TYPE deployment_by_project_${project.replace(/[^a-zA-Z0-9]/g, '_')} gauge
deployment_by_project_${project.replace(/[^a-zA-Z0-9]/g, '_')} ${count} ${timestamp}\n\n`;
  });

  // Ajouter des métriques par branche si disponibles  
  Object.entries(metrics.deployments.by_branch).forEach(([branch, count]) => {
    result += `# HELP deployment_by_branch_${branch.replace(/[^a-zA-Z0-9]/g, '_')} Déploiements par branche
# TYPE deployment_by_branch_${branch.replace(/[^a-zA-Z0-9]/g, '_')} gauge
deployment_by_branch_${branch.replace(/[^a-zA-Z0-9]/g, '_')} ${count} ${timestamp}\n\n`;
  });

  return result;
}

// Fonction principale de collecte des métriques
async function collectMetrics() {
  console.log('📊 Collecte des métriques...');
  
  await Promise.all([
    fetchPortManagerMetrics(),
    fetchDeploymentAPIMetrics(),
    analyzeDeployedApplications(),
    analyzeDeploymentConfigs(),
    fetchDockerMetrics()
  ]);
  
  calculateDerivedMetrics();
  
  console.log('✅ Métriques collectées:', {
    deployments: metrics.deployments.total,
    applications: metrics.applications.active,
    ports: metrics.infrastructure.ports_allocated
  });
}

// Serveur HTTP pour exposer les métriques
const server = createServer(async (req, res) => {
  if (req.url === '/metrics' && req.method === 'GET') {
    // Collecter les métriques en temps réel
    await collectMetrics();
    
    res.writeHead(200, {
      'Content-Type': 'text/plain; version=0.0.4; charset=utf-8'
    });
    
    res.end(generatePrometheusMetrics());
  } else if (req.url === '/health' && req.method === 'GET') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      status: 'healthy',
      service: 'deployment-metrics-exporter',
      uptime: process.uptime(),
      last_collection: new Date().toISOString()
    }));
  } else {
    res.writeHead(404, { 'Content-Type': 'text/plain' });
    res.end('Not Found');
  }
});

// Démarrage du serveur
server.listen(PORT, () => {
  console.log(`🚀 Deployment Metrics Exporter démarré sur le port ${PORT}`);
  console.log(`📊 Métriques disponibles sur: http://localhost:${PORT}/metrics`);
  console.log(`🏥 Health check sur: http://localhost:${PORT}/health`);
  
  // Collecte initiale des métriques
  collectMetrics();
  
  // Collecte périodique (toutes les 30 secondes)
  setInterval(collectMetrics, 30000);
});

// Gestion propre de l'arrêt
process.on('SIGTERM', () => {
  console.log('🛑 Arrêt du Deployment Metrics Exporter...');
  server.close(() => {
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  console.log('🛑 Arrêt du Deployment Metrics Exporter...');
  server.close(() => {
    process.exit(0);
  });
});