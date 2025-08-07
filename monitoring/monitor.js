const express = require('express');
const fs = require('fs');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 8080;

// Middleware
app.use(express.json());

// Storage for metrics and logs
let metrics = {
  servers: {},
  systemStats: {
    startTime: Date.now(),
    totalRequests: 0,
    errorCount: 0,
    lastUpdate: Date.now()
  },
  history: []
};

// Log file path
const logDir = '/logs';
const logFile = path.join(logDir, 'ai-first-monitoring.log');

// Ensure log directory exists
if (!fs.existsSync(logDir)) {
  fs.mkdirSync(logDir, { recursive: true });
}

// Logging function
function log(level, message, data = null) {
  const timestamp = new Date().toISOString();
  const logEntry = {
    timestamp,
    level,
    message,
    data
  };
  
  // Console output
  console.log(`[${timestamp}] ${level.toUpperCase()}: ${message}`, data ? JSON.stringify(data) : '');
  
  // File output
  try {
    fs.appendFileSync(logFile, JSON.stringify(logEntry) + '\n');
  } catch (error) {
    console.error('Failed to write to log file:', error);
  }
}

// Metric collection
function collectMetrics() {
  const now = Date.now();
  const uptime = now - metrics.systemStats.startTime;
  
  const currentMetrics = {
    timestamp: now,
    uptime: uptime,
    totalRequests: metrics.systemStats.totalRequests,
    errorCount: metrics.systemStats.errorCount,
    servers: Object.keys(metrics.servers).length,
    healthyServers: Object.values(metrics.servers).filter(s => s.status === 'healthy').length
  };
  
  // Keep last 100 metric points
  metrics.history.push(currentMetrics);
  if (metrics.history.length > 100) {
    metrics.history.shift();
  }
  
  metrics.systemStats.lastUpdate = now;
  
  log('info', 'Metrics collected', currentMetrics);
}

// Server health check endpoint
app.post('/api/health-check', (req, res) => {
  metrics.systemStats.totalRequests++;
  
  const { serverId, serverName, status, responseTime, error } = req.body;
  
  if (!serverId || !serverName || !status) {
    metrics.systemStats.errorCount++;
    return res.status(400).json({ error: 'Missing required fields' });
  }
  
  // Update server metrics
  metrics.servers[serverId] = {
    name: serverName,
    status,
    responseTime,
    error,
    lastChecked: Date.now(),
    checksCount: (metrics.servers[serverId]?.checksCount || 0) + 1
  };
  
  log('info', `Health check for ${serverName}`, {
    serverId,
    status,
    responseTime,
    error
  });
  
  res.json({ success: true, message: 'Health check recorded' });
});

// Get current metrics
app.get('/api/metrics', (req, res) => {
  metrics.systemStats.totalRequests++;
  
  collectMetrics();
  
  res.json({
    current: {
      timestamp: Date.now(),
      uptime: Date.now() - metrics.systemStats.startTime,
      totalRequests: metrics.systemStats.totalRequests,
      errorCount: metrics.systemStats.errorCount,
      servers: metrics.servers,
      serverCount: Object.keys(metrics.servers).length,
      healthyCount: Object.values(metrics.servers).filter(s => s.status === 'healthy').length
    },
    history: metrics.history.slice(-20) // Last 20 data points
  });
});

// Get server-specific metrics
app.get('/api/metrics/:serverId', (req, res) => {
  metrics.systemStats.totalRequests++;
  
  const serverId = req.params.serverId;
  const server = metrics.servers[serverId];
  
  if (!server) {
    metrics.systemStats.errorCount++;
    return res.status(404).json({ error: 'Server not found' });
  }
  
  res.json({
    serverId,
    ...server,
    history: metrics.history.map(h => ({
      timestamp: h.timestamp,
      status: server.status,
      responseTime: server.responseTime
    })).slice(-20)
  });
});

// Get system logs
app.get('/api/logs', (req, res) => {
  metrics.systemStats.totalRequests++;
  
  const limit = parseInt(req.query.limit) || 100;
  const level = req.query.level;
  
  try {
    const logs = fs.readFileSync(logFile, 'utf8')
      .split('\n')
      .filter(line => line.trim())
      .map(line => {
        try {
          return JSON.parse(line);
        } catch {
          return null;
        }
      })
      .filter(log => log !== null);
    
    let filteredLogs = logs;
    if (level) {
      filteredLogs = logs.filter(log => log.level === level);
    }
    
    res.json({
      logs: filteredLogs.slice(-limit),
      total: filteredLogs.length,
      filtered: !!level
    });
  } catch (error) {
    metrics.systemStats.errorCount++;
    log('error', 'Failed to read logs', error);
    res.status(500).json({ error: 'Failed to read logs' });
  }
});

// Health endpoint
app.get('/api/health', (req, res) => {
  metrics.systemStats.totalRequests++;
  
  res.json({
    status: 'healthy',
    timestamp: Date.now(),
    uptime: Date.now() - metrics.systemStats.startTime,
    version: '1.0.0'
  });
});

// Monitoring dashboard
app.get('/', (req, res) => {
  res.send(`
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AI-First Monitoring Dashboard</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: #1a1a2e;
            color: #eee;
            min-height: 100vh;
            padding: 20px;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
        }
        .header {
            text-align: center;
            margin-bottom: 30px;
            padding: 20px;
            background: linear-gradient(135deg, #16213e 0%, #0f3460 100%);
            border-radius: 10px;
        }
        .header h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
            color: #00d4ff;
        }
        .metrics-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        .metric-card {
            background: #16213e;
            padding: 20px;
            border-radius: 10px;
            border: 1px solid #0f3460;
            transition: transform 0.3s ease;
        }
        .metric-card:hover {
            transform: translateY(-5px);
            border-color: #00d4ff;
        }
        .metric-value {
            font-size: 2em;
            font-weight: bold;
            color: #00d4ff;
            margin-bottom: 5px;
        }
        .metric-label {
            color: #aaa;
            font-size: 0.9em;
            text-transform: uppercase;
            letter-spacing: 1px;
        }
        .servers-section {
            background: #16213e;
            padding: 25px;
            border-radius: 10px;
            border: 1px solid #0f3460;
            margin-bottom: 30px;
        }
        .servers-section h2 {
            color: #00d4ff;
            margin-bottom: 20px;
            font-size: 1.5em;
        }
        .server-list {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 15px;
        }
        .server-item {
            background: #0f3460;
            padding: 15px;
            border-radius: 8px;
            border-left: 4px solid #ccc;
            transition: all 0.3s ease;
        }
        .server-item.healthy {
            border-left-color: #00ff88;
        }
        .server-item.unhealthy {
            border-left-color: #ff4757;
        }
        .server-name {
            font-weight: bold;
            color: #00d4ff;
            margin-bottom: 5px;
        }
        .server-status {
            font-size: 0.9em;
            margin-bottom: 5px;
        }
        .server-stats {
            font-size: 0.8em;
            color: #aaa;
        }
        .logs-section {
            background: #16213e;
            padding: 25px;
            border-radius: 10px;
            border: 1px solid #0f3460;
        }
        .logs-section h2 {
            color: #00d4ff;
            margin-bottom: 20px;
            font-size: 1.5em;
        }
        .log-entry {
            background: #0f3460;
            padding: 10px;
            border-radius: 5px;
            margin-bottom: 10px;
            font-family: monospace;
            font-size: 0.9em;
        }
        .log-timestamp {
            color: #aaa;
            margin-right: 10px;
        }
        .log-level {
            padding: 2px 6px;
            border-radius: 3px;
            font-size: 0.8em;
            margin-right: 10px;
        }
        .log-level.info { background: #00d4ff; color: #000; }
        .log-level.error { background: #ff4757; color: #fff; }
        .log-level.warn { background: #ffa502; color: #000; }
        .refresh-btn {
            position: fixed;
            bottom: 30px;
            right: 30px;
            width: 60px;
            height: 60px;
            border-radius: 50%;
            background: #00d4ff;
            color: #000;
            border: none;
            font-size: 1.5em;
            cursor: pointer;
            box-shadow: 0 5px 15px rgba(0, 212, 255, 0.3);
            transition: all 0.3s ease;
        }
        .refresh-btn:hover {
            transform: scale(1.1);
            box-shadow: 0 8px 20px rgba(0, 212, 255, 0.5);
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📊 AI-First Monitoring</h1>
            <p>Real-time monitoring and metrics for your MCP servers</p>
        </div>
        
        <div class="metrics-grid" id="metricsGrid">
            <!-- Metrics will be populated here -->
        </div>
        
        <div class="servers-section">
            <h2>🖥️ Server Status</h2>
            <div class="server-list" id="serverList">
                <!-- Servers will be populated here -->
            </div>
        </div>
        
        <div class="logs-section">
            <h2>📝 Recent Logs</h2>
            <div id="logsList">
                <!-- Logs will be populated here -->
            </div>
        </div>
    </div>
    
    <button class="refresh-btn" onclick="loadData()" title="Refresh">
        🔄
    </button>
    
    <script>
        async function loadData() {
            try {
                // Load metrics
                const metricsResponse = await fetch('/api/metrics');
                const metrics = await metricsResponse.json();
                
                // Update metrics grid
                const metricsGrid = document.getElementById('metricsGrid');
                metricsGrid.innerHTML = \`
                    <div class="metric-card">
                        <div class="metric-value">\${Math.floor(metrics.current.uptime / 1000 / 60)}</div>
                        <div class="metric-label">Uptime (minutes)</div>
                    </div>
                    <div class="metric-card">
                        <div class="metric-value">\${metrics.current.totalRequests}</div>
                        <div class="metric-label">Total Requests</div>
                    </div>
                    <div class="metric-card">
                        <div class="metric-value">\${metrics.current.errorCount}</div>
                        <div class="metric-label">Error Count</div>
                    </div>
                    <div class="metric-card">
                        <div class="metric-value">\${metrics.current.healthyCount}/\${metrics.current.serverCount}</div>
                        <div class="metric-label">Healthy Servers</div>
                    </div>
                \`;
                
                // Update server list
                const serverList = document.getElementById('serverList');
                serverList.innerHTML = '';
                
                Object.entries(metrics.current.servers).forEach(([id, server]) => {
                    const serverItem = document.createElement('div');
                    serverItem.className = \`server-item \${server.status}\`;
                    serverItem.innerHTML = \`
                        <div class="server-name">\${server.name}</div>
                        <div class="server-status">Status: \${server.status}</div>
                        <div class="server-stats">
                            Response Time: \${server.responseTime || 'N/A'}ms | 
                            Checks: \${server.checksCount || 0} | 
                            Last: \${server.lastChecked ? new Date(server.lastChecked).toLocaleTimeString() : 'Never'}
                        </div>
                    \`;
                    serverList.appendChild(serverItem);
                });
                
                // Load logs
                const logsResponse = await fetch('/api/logs?limit=10');
                const logs = await logsResponse.json();
                
                const logsList = document.getElementById('logsList');
                logsList.innerHTML = '';
                
                logs.logs.reverse().forEach(log => {
                    const logEntry = document.createElement('div');
                    logEntry.className = 'log-entry';
                    logEntry.innerHTML = \`
                        <span class="log-timestamp">\${new Date(log.timestamp).toLocaleTimeString()}</span>
                        <span class="log-level \${log.level}">\${log.level.toUpperCase()}</span>
                        <span class="log-message">\${log.message}</span>
                    \`;
                    logsList.appendChild(logEntry);
                });
                
            } catch (error) {
                console.error('Error loading data:', error);
            }
        }
        
        // Load data on page load
        document.addEventListener('DOMContentLoaded', loadData);
        
        // Auto-refresh every 10 seconds
        setInterval(loadData, 10000);
    </script>
</body>
</html>
  `);
});

// Error handling middleware
app.use((error, req, res, next) => {
  metrics.systemStats.errorCount++;
  log('error', 'Server error', error);
  res.status(500).json({ error: 'Internal server error' });
});

// Start server
const server = app.listen(PORT, () => {
  log('info', `AI-First Monitoring server running on port ${PORT}`);
  log('info', `Monitoring URL: http://localhost:${PORT}`);
  
  // Collect initial metrics
  collectMetrics();
});

// Collect metrics every 30 seconds
setInterval(collectMetrics, 30000);

// Graceful shutdown
process.on('SIGTERM', () => {
  log('info', 'Received SIGTERM, shutting down gracefully');
  server.close(() => {
    log('info', 'Server closed');
    process.exit(0);
  });
});

module.exports = app; 